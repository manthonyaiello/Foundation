with Interfaces;
with Foundation_Spark.SHA2.Preprocessing;
with Foundation_Spark.SHA2.SHA256;

package body Foundation_Spark.HMAC.SHA256_Impl with
  SPARK_Mode
is

   use type Interfaces.Unsigned_32;
   use type SHA2.Words_32;
   use type SHA2.SHA256_Bytes.Byte_Array;

   subtype Bit_Index is SHA2.Bit_Index;
   subtype Bits is SHA2.Bits;
   subtype Stream_Index is SHA2.SHA256_Bytes.Byte_Index;

   function Xor_Pad (K0 : Key_Block; X : Byte) return Key_Block with
     Post =>
       (for all J in Key_Block'Range => Xor_Pad'Result (J) = (K0 (J) xor X));
   --  K0 xor a pad: every byte of K0 xored with X.
   --  @param K0 The key block.
   --  @param X The pad's byte, 0x36 (ipad) or 0x5C (opad).
   --  @return K0 xor X, byte by byte.

   function Xor_Pad (K0 : Key_Block; X : Byte) return Key_Block is
      P : Key_Block := [others => 0];
   begin
      for J in Key_Block'Range loop
         P (J) := K0 (J) xor X;
         pragma Loop_Invariant
           (for all J2 in 0 .. J => P (J2) = (K0 (J2) xor X));
      end loop;
      return P;
   end Xor_Pad;

   function Inner_Prefix (Key : Byte_Array; M : Byte_Array) return Byte_Array
   is (Xor_Pad (Init_Key (Key), 16#36#) & M)
   with
     Ghost,
     Pre => Key'Length < SHA2.SHA256_Bytes.Max_Bytes
            and then M'Length < Max_Text;
   --  What the inner hash absorbs for Key and the text M: K0 xor ipad,
   --  then M, indexed from 0.
   --  @param Key The key.
   --  @param M The text.
   --  @return K0 xor ipad followed by M.

   --------------------------------
   -- Models, Absorbed, Finished --
   --------------------------------

   function Models
     (C : Context; Key : Byte_Array; M : Byte_Array) return Boolean
   is (M'Length < Max_Text
       and then SHA2.SHA256_Stream.Models (C.Inner, Inner_Prefix (Key, M))
       and then C.O_Pad = Xor_Pad (Init_Key (Key), 16#5C#));

   function Absorbed
     (C0 : Context; Data : Byte_Array; C1 : Context) return Boolean
   is (SHA2.SHA256_Stream.Absorbed (C0.Inner, Data, C1.Inner)
       and then C1.O_Pad = C0.O_Pad);

   function Finished (C : Context; D : Digest) return Boolean is
     (D
      = SHA2.SHA256_Bytes.Hash_Bytes
          (C.O_Pad & SHA2.SHA256_Stream.Final (C.Inner)));

   ---------------------------
   -- Ghost lemmas (bodies) --
   ---------------------------

   procedure Lemma_Word_Of_Ext
     (P, Q : Bits; F : Bit_Index; Count : Natural)
   with
     Ghost,
     Pre                =>
       Count <= 32
       and then F >= P'First
       and then F >= Q'First
       and then F + Bit_Index (Count) - 1 <= P'Last
       and then F + Bit_Index (Count) - 1 <= Q'Last
       and then
         (for all K in F .. F + Bit_Index (Count) - 1 => P (K) = Q (K)),
     Post               =>
       SHA2.SHA256.Word_Of (P, F, Count) = SHA2.SHA256.Word_Of (Q, F, Count),
     Subprogram_Variant => (Decreases => Count);
   --  Word_Of reads only the Count bits from F, so two sequences that agree
   --  there give the same word.
   --  @param P One bit sequence.
   --  @param Q The other.
   --  @param F The first bit read.
   --  @param Count The number of bits read.

   procedure Lemma_Word_Of_Ext
     (P, Q : Bits; F : Bit_Index; Count : Natural)
   is
   begin
      if Count > 0 then
         Lemma_Word_Of_Ext (P, Q, F, Count - 1);
      end if;
   end Lemma_Word_Of_Ext;

   procedure Lemma_Parse_Block_Ext (P, Q : Bits; I : Bit_Index) with
     Ghost,
     Pre  =>
       P'First = 0
       and then Q'First = 0
       and then P'Length = Q'Length
       and then I < Bit_Index'Last / 512
       and then (I + 1) * 512 <= P'Length
       and then P = Q,
     Post => SHA2.SHA256.Parse_Block (P, I) = SHA2.SHA256.Parse_Block (Q, I);
   --  Parse_Block of "=" sequences is "=": block I, word by word.
   --  @param P One bit sequence.
   --  @param Q The other, "=" to P.
   --  @param I The block's index.

   procedure Lemma_Parse_Block_Ext (P, Q : Bits; I : Bit_Index) is
   begin
      for J in 0 .. 15 loop
         Lemma_Word_Of_Ext (P, Q, (16 * I + Bit_Index (J)) * 32, 32);
         pragma Loop_Invariant
           (for all J2 in 0 .. J =>
              SHA2.SHA256.Word_Of (P, (16 * I + Bit_Index (J2)) * 32, 32)
              = SHA2.SHA256.Word_Of (Q, (16 * I + Bit_Index (J2)) * 32, 32));
      end loop;
   end Lemma_Parse_Block_Ext;

   procedure Lemma_Hash_Ext (X, Y : Bits) with
     Ghost,
     Pre  =>
       X'First = 0
       and then Y'First = 0
       and then X'Length = Y'Length
       and then X'Length < SHA2.SHA256.Max_Length
       and then X = Y,
     Post => SHA2.SHA256.Hash (X) = SHA2.SHA256.Hash (Y);
   --  Extensionality of the spec's SHA256.Hash: "=" messages have "="
   --  digests. The provers do not take Ada's array "=" for equality, so
   --  this goes through Pad, Parse and the fold.
   --  @param X One message.
   --  @param Y The other, "=" to X.

   procedure Lemma_Hash_Ext (X, Y : Bits) is
      N  : constant Bit_Index := SHA2.SHA256.N (X'Length);
      PX : constant Bits := SHA2.SHA256.Pad (X);
      PY : constant Bits := SHA2.SHA256.Pad (Y);
   begin
      SHA2.SHA256_Bytes.Lemma_Pad (X);
      SHA2.SHA256_Bytes.Lemma_Pad (Y);
      pragma Assert (PX'Length = 512 * N and then PY'Length = 512 * N);
      pragma Assert (PX = PY);
      for I in 0 .. N - 1 loop
         Lemma_Parse_Block_Ext (PX, PY, I);
         pragma Loop_Invariant
           (for all I2 in 0 .. I =>
              SHA2.SHA256.Parse (PX, N) (I2) = SHA2.SHA256.Parse (PY, N) (I2));
      end loop;
      SHA2.SHA256_Bytes.Lemma_Foldl_Step_Ext
        (SHA2.Preprocessing.H0_256,
         SHA2.SHA256.Parse (PX, N),
         SHA2.SHA256.Parse (PY, N),
         N);
   end Lemma_Hash_Ext;

   procedure Lemma_Byte_Bit_Xor (A, B : Byte) with
     Ghost,
     Post =>
       (for all J in 0 .. 7 =>
          SHA2.SHA256_Bytes.Byte_Bit (A xor B, J)
          = (SHA2.SHA256_Bytes.Byte_Bit (A, J)
             xor SHA2.SHA256_Bytes.Byte_Bit (B, J)));
   --  A bit of a xor is the xor of the bits.
   --  @param A One byte.
   --  @param B The other.

   procedure Lemma_Byte_Bit_Xor (A, B : Byte) is null;

   procedure Lemma_Bits_Xor (P, K : Key_Block; X : Byte) with
     Ghost,
     Pre  => (for all J in Key_Block'Range => P (J) = (K (J) xor X)),
     Post =>
       (for all I in 0 .. Bit_Index (511) =>
          SHA2.SHA256_Bytes.Bits_Of (P) (I)
          = (SHA2.SHA256_Bytes.Bits_Of (K) (I)
             xor SHA2.SHA256_Bytes.Byte_Bit (X, Natural (I mod 8))));
   --  The bits of a block xored with a byte X everywhere, K0 xor ipad or
   --  K0 xor opad, are K's bits xored with X's.
   --  @param P The block xored with X.
   --  @param K The block.
   --  @param X The byte.

   procedure Lemma_Bits_Xor (P, K : Key_Block; X : Byte) is
   begin
      for J in Key_Block'Range loop
         Lemma_Byte_Bit_Xor (K (J), X);
         pragma Loop_Invariant
           (for all J2 in 0 .. J =>
              (for all T in 0 .. 7 =>
                 SHA2.SHA256_Bytes.Byte_Bit (P (J2), T)
                 = (SHA2.SHA256_Bytes.Byte_Bit (K (J2), T)
                    xor SHA2.SHA256_Bytes.Byte_Bit (X, T))));
      end loop;
   end Lemma_Bits_Xor;

   procedure Lemma_Bits_Of_Append
     (M : Byte_Array; P : Key_Block; T : Byte_Array)
   with
     Ghost,
     Pre  =>
       T'Length < Max_Text
       and then M'First = 0
       and then M'Length = 64 + T'Length
       and then (for all J in Key_Block'Range => M (J) = P (J))
       and then
         (for all J in 0 .. Stream_Index (T'Length) - 1 =>
            M (64 + J) = T (T'First + J)),
     Post =>
       (for all I in 0 .. 8 * Bit_Index (M'Length) - 1 =>
          SHA2.SHA256_Bytes.Bits_Of (M) (I)
          = (if I < 512 then SHA2.SHA256_Bytes.Bits_Of (P) (I)
             else SHA2.SHA256_Bytes.Bits_Of (T) (I - 512)));
   --  The bits of a 64-byte block followed by T are the block's bits
   --  followed by T's.
   --  @param M The block followed by T, indexed from 0.
   --  @param P The block.
   --  @param T The bytes after it.

   procedure Lemma_Bits_Of_Append
     (M : Byte_Array; P : Key_Block; T : Byte_Array) is null;

   procedure Lemma_Message_Bits
     (M : Byte_Array; P : Key_Block; T : Byte_Array; X, Y : Bits)
   with
     Ghost,
     Pre  =>
       T'Length < Max_Text
       and then M'First = 0
       and then M'Length = 64 + T'Length
       and then (for all J in Key_Block'Range => M (J) = P (J))
       and then
         (for all J in 0 .. Stream_Index (T'Length) - 1 =>
            M (64 + J) = T (T'First + J))
       and then X'First = 0
       and then X'Length = 512
       and then
         (for all I in 0 .. Bit_Index (511) =>
            SHA2.SHA256_Bytes.Bits_Of (P) (I) = X (I))
       and then Y'First = 0
       and then SHA2.SHA256_Bytes.Bits_Of (T) = Y,
     Post => SHA2.SHA256_Bytes.Bits_Of (M) = X & Y;
   --  The bits of a 64-byte block P followed by T, when P's bits are X
   --  and T's are Y, are X followed by Y.
   --  @param M P followed by T, indexed from 0.
   --  @param P The block.
   --  @param T The bytes after it.
   --  @param X P's bits.
   --  @param Y T's bits.

   procedure Lemma_Message_Bits
     (M : Byte_Array; P : Key_Block; T : Byte_Array; X, Y : Bits)
   is
   begin
      Lemma_Bits_Of_Append (M, P, T);
      pragma Assert (Bits'(X & Y)'Length = 8 * Bit_Index (M'Length));
   end Lemma_Message_Bits;

   procedure Lemma_Join_Bits (Key : Byte_Array) with
     Ghost,
     Pre  => Key'Length < SHA2.SHA256_Bytes.Max_Bytes,
     Post => Join (To_Bytes (Key)) = SHA2.SHA256_Bytes.Bits_Of (Key);
   --  The spec's `join` of a key's bytes is SHA256_Bytes' Bits_Of of them.
   --  @param Key The key.

   procedure Lemma_Join_Bits (Key : Byte_Array) is null;

   procedure Lemma_Pad_Bits (X : Byte) with
     Ghost,
     Post =>
       Join (Repeat (64, X))'Length = 512
       and then
         (for all I in 0 .. Bit_Index (511) =>
            Join (Repeat (64, X)) (I)
            = SHA2.SHA256_Bytes.Byte_Bit (X, Natural (I mod 8)));
   --  The bits of the spec's pads, `join (repeat`{64} X)`: bit I is bit
   --  I mod 8 of X.
   --  @param X The pad's byte, 0x36 or 0x5C.

   procedure Lemma_Pad_Bits (X : Byte) is null;

   procedure Lemma_Digest_Bits (A, B : Digest) with
     Ghost,
     Pre  => A = B,
     Post => SHA2.SHA256_Bytes.Bits_Of (A) = SHA2.SHA256_Bytes.Bits_Of (B);
   --  "=" digests have "=" bits.
   --  @param A One digest.
   --  @param B The other, "=" to A.

   procedure Lemma_Digest_Bits (A, B : Digest) is null;

   procedure Lemma_Bits_Trans (A, B, C : Bits) with
     Ghost,
     Pre  => A = B and then B = C,
     Post => A = C;
   --  Ada's "=" on bit sequences is transitive. Stated so that a chain of
   --  "=" through function results is one step for the provers.
   --  @param A The first sequence.
   --  @param B The second, "=" to A.
   --  @param C The third, "=" to B.

   procedure Lemma_Bits_Trans (A, B, C : Bits) is null;

   function Inner_Message (K : Bytes; T : Bits) return Bits is
     ((HMAC.SHA256.HMAC_init (K) xor HMAC.SHA256.Ipad) & T)
   with
     Ghost,
     Pre =>
       K'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then T'First = 0
       and then T'Length < 8 * Bit_Index (Max_Text);
   --  The inner hash's message in the spec, `(K0 ^ ipad) # text`
   --  (Main.cry:43).
   --  @param K The key.
   --  @param T The text's bits.
   --  @return The bits Hn hashes.

   function Outer_Message (K : Bytes; T : Bits) return Bits is
     ((HMAC.SHA256.HMAC_init (K) xor HMAC.SHA256.Opad)
      & SHA2.SHA256.Hash (Inner_Message (K, T)))
   with
     Ghost,
     Pre =>
       K'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then T'First = 0
       and then T'Length < 8 * Bit_Index (Max_Text);
   --  The outer hash's message in the spec, `(K0 ^ opad) # Hn (...)`
   --  (Main.cry:42).
   --  @param K The key.
   --  @param T The text's bits.
   --  @return The bits HL hashes.

   procedure Lemma_HMAC_Unfold (K : Bytes; T : Bits) with
     Ghost,
     Pre  =>
       K'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then T'First = 0
       and then T'Length < 8 * Bit_Index (Max_Text),
     Post =>
       SHA2.SHA256.Hash (Outer_Message (K, T))'First = 0
       and then SHA2.SHA256.Hash (Outer_Message (K, T))'Length = 256
       and then
         HMAC.SHA256.HMAC (K, T, 256)
         = SHA2.SHA256.Hash (Outer_Message (K, T));
   --  The spec's HMAC at λ = 256 unfolded, with Hk, Hn and HL the SHA-256
   --  hash, as HMAC.SHA256 instantiates them: the slice of the first 256
   --  bits is the whole outer digest. Stated apart so that the provers
   --  see the unfolding with nothing else in context.
   --  @param K The key.
   --  @param T The text's bits.

   procedure Lemma_HMAC_Unfold (K : Bytes; T : Bits) is null;

   procedure Lemma_HMAC
     (Key, Text           : Byte_Array;
      K0, I_Pad, O_Pad    : Key_Block;
      M_In, M_Out         : Byte_Array;
      Inner, Result       : Digest)
   with
     Ghost,
     Pre  =>
       Key'Length < SHA2.SHA256_Bytes.Max_Bytes
       and then Text'Length < Max_Text
       and then SHA2.SHA256_Bytes.Bits_Of (K0)
                = HMAC.SHA256.HMAC_init (To_Bytes (Key))
       and then
         (for all J in Key_Block'Range =>
            I_Pad (J) = (K0 (J) xor 16#36#)
            and then O_Pad (J) = (K0 (J) xor 16#5C#))
       and then M_In'First = 0
       and then M_In'Length = 64 + Text'Length
       and then (for all J in Key_Block'Range => M_In (J) = I_Pad (J))
       and then
         (for all J in 0 .. Stream_Index (Text'Length) - 1 =>
            M_In (64 + J) = Text (Text'First + J))
       and then Inner = SHA2.SHA256_Bytes.Hash_Bytes (M_In)
       and then M_Out'First = 0
       and then M_Out'Length = 96
       and then (for all J in Key_Block'Range => M_Out (J) = O_Pad (J))
       and then (for all J in Digest'Range => M_Out (64 + J) = Inner (J))
       and then Result = SHA2.SHA256_Bytes.Hash_Bytes (M_Out),
     Post =>
       SHA2.SHA256_Bytes.Bits_Of (Result)
       = HMAC.SHA256.HMAC
           (To_Bytes (Key), SHA2.SHA256_Bytes.Bits_Of (Text), 256);
   --  The bits of the two streams' messages are the spec's: M_In, K0 xor
   --  ipad then Text, is on the bits `(K0 ^ ipad) # text`, and M_Out, K0
   --  xor opad then the inner digest, is `(K0 ^ opad) # Hn (...)`. So
   --  Result, Hash_Bytes (M_Out), is on the bits the spec's HMAC at
   --  λ = 256.
   --  @param Key The key.
   --  @param Text The text.
   --  @param K0 The key as one block, HMAC_init on the bits.
   --  @param I_Pad K0 xor ipad.
   --  @param O_Pad K0 xor opad.
   --  @param M_In The inner hash's message, I_Pad then Text.
   --  @param M_Out The outer hash's message, O_Pad then Inner.
   --  @param Inner The inner digest.
   --  @param Result The outer digest.

   procedure Lemma_HMAC
     (Key, Text           : Byte_Array;
      K0, I_Pad, O_Pad    : Key_Block;
      M_In, M_Out         : Byte_Array;
      Inner, Result       : Digest)
   is
      KB    : constant Bytes := To_Bytes (Key);
      S_In  : constant Bits :=
        Inner_Message (KB, SHA2.SHA256_Bytes.Bits_Of (Text));
      S_Out : constant Bits :=
        Outer_Message (KB, SHA2.SHA256_Bytes.Bits_Of (Text));
   begin
      Lemma_Pad_Bits (16#36#);
      Lemma_Pad_Bits (16#5C#);
      Lemma_Bits_Xor (I_Pad, K0, 16#36#);
      Lemma_Bits_Xor (O_Pad, K0, 16#5C#);

      --  The inner hash.
      Lemma_Bits_Of_Append (M_In, I_Pad, Text);
      pragma Assert
        (for all I in 0 .. Bit_Index (511) =>
           SHA2.SHA256_Bytes.Bits_Of (I_Pad) (I)
           = Bits'(HMAC.SHA256.HMAC_init (KB) xor HMAC.SHA256.Ipad) (I));
      pragma Assert (SHA2.SHA256_Bytes.Bits_Of (M_In) = S_In);
      Lemma_Hash_Ext (SHA2.SHA256_Bytes.Bits_Of (M_In), S_In);
      SHA2.SHA256_Bytes.Lemma_Hash_Bytes (M_In);
      Lemma_Digest_Bits (Inner, SHA2.SHA256_Bytes.Hash_Bytes (M_In));
      Lemma_Bits_Trans
        (SHA2.SHA256_Bytes.Bits_Of (Inner),
         SHA2.SHA256_Bytes.Bits_Of (SHA2.SHA256_Bytes.Hash_Bytes (M_In)),
         SHA2.SHA256.Hash (SHA2.SHA256_Bytes.Bits_Of (M_In)));
      Lemma_Bits_Trans
        (SHA2.SHA256_Bytes.Bits_Of (Inner),
         SHA2.SHA256.Hash (SHA2.SHA256_Bytes.Bits_Of (M_In)),
         SHA2.SHA256.Hash (S_In));

      --  The outer hash.
      pragma Assert
        (for all I in 0 .. Bit_Index (511) =>
           SHA2.SHA256_Bytes.Bits_Of (O_Pad) (I)
           = Bits'(HMAC.SHA256.HMAC_init (KB) xor HMAC.SHA256.Opad) (I));
      Lemma_Message_Bits
        (M_Out, O_Pad, Inner,
         HMAC.SHA256.HMAC_init (KB) xor HMAC.SHA256.Opad,
         SHA2.SHA256.Hash (S_In));
      pragma Assert (SHA2.SHA256_Bytes.Bits_Of (M_Out) = S_Out);
      Lemma_Hash_Ext (SHA2.SHA256_Bytes.Bits_Of (M_Out), S_Out);
      SHA2.SHA256_Bytes.Lemma_Hash_Bytes (M_Out);
      Lemma_Digest_Bits (Result, SHA2.SHA256_Bytes.Hash_Bytes (M_Out));
      Lemma_Bits_Trans
        (SHA2.SHA256_Bytes.Bits_Of (Result),
         SHA2.SHA256_Bytes.Bits_Of (SHA2.SHA256_Bytes.Hash_Bytes (M_Out)),
         SHA2.SHA256.Hash (SHA2.SHA256_Bytes.Bits_Of (M_Out)));
      Lemma_Bits_Trans
        (SHA2.SHA256_Bytes.Bits_Of (Result),
         SHA2.SHA256.Hash (SHA2.SHA256_Bytes.Bits_Of (M_Out)),
         SHA2.SHA256.Hash (S_Out));
      Lemma_HMAC_Unfold (KB, SHA2.SHA256_Bytes.Bits_Of (Text));
      Lemma_Bits_Trans
        (SHA2.SHA256_Bytes.Bits_Of (Result),
         SHA2.SHA256.Hash (S_Out),
         HMAC.SHA256.HMAC (KB, SHA2.SHA256_Bytes.Bits_Of (Text), 256));
   end Lemma_HMAC;

   --------------
   -- Init_Key --
   --------------

   function Init_Key (Key : Byte_Array) return Key_Block is
      K0 : Key_Block := [others => 0];
   begin
      Lemma_Join_Bits (Key);
      if Key'Length > 64 then
         declare
            D : constant Digest := SHA2.SHA256_Stream.Hash (Key);
         begin
            K0 (0 .. 31) := D;
            pragma Assert (for all J in Digest'Range => K0 (J) = D (J));
            pragma Assert
              (for all J in Stream_Index'(32) .. 63 => K0 (J) = 0);
            Lemma_Hash_Ext
              (Join (To_Bytes (Key)), SHA2.SHA256_Bytes.Bits_Of (Key));
            Lemma_Bits_Trans
              (SHA2.SHA256_Bytes.Bits_Of (D),
               SHA2.SHA256.Hash (SHA2.SHA256_Bytes.Bits_Of (Key)),
               SHA2.SHA256.Hash (Join (To_Bytes (Key))));
            pragma Assert
              (HMAC.SHA256.HMAC_init (To_Bytes (Key))
               = SHA2.SHA256.Hash (Join (To_Bytes (Key))) & Zero (256));
            pragma Assert
              (for all I in 0 .. Bit_Index (255) =>
                 SHA2.SHA256_Bytes.Bits_Of (K0) (I)
                 = SHA2.SHA256_Bytes.Bits_Of (D) (I));
            pragma Assert
              (for all I in Bit_Index'(256) .. 511 =>
                 not SHA2.SHA256_Bytes.Bits_Of (K0) (I));
            pragma Assert
              (for all I in 0 .. Bit_Index (511) =>
                 SHA2.SHA256_Bytes.Bits_Of (K0) (I)
                 = HMAC.SHA256.HMAC_init (To_Bytes (Key)) (I));
         end;
      else
         K0 (0 .. Stream_Index (Key'Length) - 1) := Key;
         pragma Assert
           (for all J in 0 .. Stream_Index (Key'Length) - 1 =>
              K0 (J) = Key (Key'First + J));
         pragma Assert
           (for all J in Stream_Index (Key'Length) .. 63 => K0 (J) = 0);
         pragma Assert
           (for all I in 0 .. 8 * Bit_Index (Key'Length) - 1 =>
              SHA2.SHA256_Bytes.Bits_Of (K0) (I)
              = SHA2.SHA256_Bytes.Bits_Of (Key) (I));
         pragma Assert
           (for all I in 8 * Bit_Index (Key'Length) .. 511 =>
              not SHA2.SHA256_Bytes.Bits_Of (K0) (I));
         pragma Assert
           (for all I in 0 .. Bit_Index (511) =>
              SHA2.SHA256_Bytes.Bits_Of (K0) (I)
              = HMAC.SHA256.HMAC_init (To_Bytes (Key)) (I));
      end if;
      return K0;
   end Init_Key;

   -----------------
   -- HMAC_SHA256 --
   -----------------

   function HMAC_SHA256 (Key : Byte_Array; Text : Byte_Array) return Digest
   is
      C  : Context;
      C0 : Context with Ghost;
   begin
      Init (C, Key);
      C0 := C;
      Update (C, Text);
      Lemma_Update (C0, Text, C, Key, SHA2.SHA256_Stream.Empty, Text);
      Lemma_Final (C, Key, Text);
      return Final (C);
   end HMAC_SHA256;

   ----------
   -- Init --
   ----------

   procedure Init (C : out Context; Key : Byte_Array) is
      K0    : constant Key_Block := Init_Key (Key);
      I_Pad : constant Key_Block := Xor_Pad (K0, 16#36#);
      C0    : SHA2.SHA256_Stream.Context with Ghost;
   begin
      C.O_Pad := Xor_Pad (K0, 16#5C#);
      SHA2.SHA256_Stream.Init (C.Inner);
      C0 := C.Inner;
      SHA2.SHA256_Stream.Update (C.Inner, I_Pad);
      SHA2.SHA256_Stream.Lemma_Update
        (C0, I_Pad, C.Inner, SHA2.SHA256_Stream.Empty,
         Inner_Prefix (Key, SHA2.SHA256_Stream.Empty));
   end Init;

   ------------
   -- Update --
   ------------

   procedure Update (C : in out Context; Data : Byte_Array) is
   begin
      SHA2.SHA256_Stream.Update (C.Inner, Data);
   end Update;

   -----------
   -- Final --
   -----------

   function Final (C : Context) return Digest is
      Inner : constant Digest := SHA2.SHA256_Stream.Final (C.Inner);
      M_Out : constant Byte_Array := C.O_Pad & Inner with Ghost;
      D     : SHA2.SHA256_Stream.Context;
      D0    : SHA2.SHA256_Stream.Context with Ghost;
   begin
      SHA2.SHA256_Stream.Init (D);
      D0 := D;
      SHA2.SHA256_Stream.Update (D, C.O_Pad);
      SHA2.SHA256_Stream.Lemma_Update
        (D0, C.O_Pad, D, SHA2.SHA256_Stream.Empty, C.O_Pad);
      D0 := D;
      SHA2.SHA256_Stream.Update (D, Inner);
      SHA2.SHA256_Stream.Lemma_Update (D0, Inner, D, C.O_Pad, M_Out);
      SHA2.SHA256_Stream.Lemma_Final (D, M_Out);
      return SHA2.SHA256_Stream.Final (D);
   end Final;

   ------------------
   -- Lemma_Update --
   ------------------

   procedure Lemma_Update
     (C0   : Context;
      Data : Byte_Array;
      C1   : Context;
      Key  : Byte_Array;
      M    : Byte_Array;
      M2   : Byte_Array)
   is
   begin
      SHA2.SHA256_Stream.Lemma_Update
        (C0.Inner, Data, C1.Inner, Inner_Prefix (Key, M),
         Inner_Prefix (Key, M2));
   end Lemma_Update;

   -----------------
   -- Lemma_Final --
   -----------------

   procedure Lemma_Final (C : Context; Key : Byte_Array; M : Byte_Array) is
      K0    : constant Key_Block := Init_Key (Key);
      I_Pad : constant Key_Block := Xor_Pad (K0, 16#36#);
      M_In  : constant Byte_Array := Inner_Prefix (Key, M);
   begin
      SHA2.SHA256_Stream.Lemma_Final (C.Inner, M_In);
      declare
         Inner : constant Digest := SHA2.SHA256_Stream.Final (C.Inner);
         M_Out : constant Byte_Array := C.O_Pad & Inner;
      begin
         Lemma_HMAC
           (Key, M, K0, I_Pad, C.O_Pad, M_In, M_Out, Inner, Final (C));
      end;
   end Lemma_Final;

end Foundation_Spark.HMAC.SHA256_Impl;
