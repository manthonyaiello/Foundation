--  The C shapes of the AES spec layer's arguments, shared by the AES shim
--  and export units.
--
--  Cryptol's C calling convention passes a numeric type parameter {k} as a
--  leading size_t, and a sequence of bytes [n][8] (nested sequences
--  flattened, so [n]Block and [n]AESWord too) as a pointer to its n bytes;
--  a result of such a type is written through a pointer passed after the
--  arguments. An Ada array parameter of a Convention C subprogram is passed
--  by reference, as a pointer to its first component, so a Block, an
--  AESWord or a Key_Bytes parameter is that pointer.
--
--  The length of [Nr k + 1]Block, [Nk k]AESWord and [k / 8][8] depends on
--  k. Their parameters are typed at the largest size Key allows (k = 256)
--  and the shims read, or write, only the first Nr k + 1, Nk k or k / 8
--  elements: Round_Keys_Of and Key_Words_Of take those prefixes, which is
--  the unconstrained Round_Keys or Key_Words that the spec's
--  Is_Round_Keys or Is_Key_Words precondition asks for. One shim then
--  serves k = 128, 192 and 256.
--
--  Not ghost: the export units use these types too.

with Interfaces.C;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.FFI.AES_Types with
  SPARK_Mode,
  Pure
is

   use Foundation_Spark.AES.Spec.Types;

   use type Interfaces.C.size_t;

   subtype C_Size is Interfaces.C.size_t;
   --  A Cryptol numeric type parameter in the C calling convention: size_t.

   subtype All_Round_Keys is Round_Keys (Round_Key_Index);
   --  The C buffer of a [Nr k + 1]Block, typed at Max_Nr + 1 blocks. Only
   --  the first Nr (k) + 1 are the caller's.

   subtype All_Key_Words is Key_Words (Key_Word_Index);
   --  The C buffer of a [Nk k]AESWord, typed at Max_Nk words. Only the
   --  first Nk (k) are the caller's.

   subtype Key_Byte_Index is Natural range 0 .. 31;
   --  The indices a Key_Bytes may use: k / 8 is at most 32.

   type Key_Bytes is array (Key_Byte_Index) of Byte;
   --  The C buffer of a [k / 8][8], the key of Main.cry's Encrypt and
   --  Decrypt as bytes (split key on the Cryptol side), typed at 32
   --  bytes. Only the first k / 8 are the caller's.

   function Is_Key_Size (K : C_Size) return Boolean
   is (K = 128 or else K = 192 or else K = 256);
   --  Whether a size_t passed for {k} meets Types.cry's Key k. Cryptol
   --  checks Key k at the call, so it always holds.
   --  @param K The key size Cryptol passed.
   --  @return Whether K is 128, 192 or 256.

   function Key_Size (K : C_Size) return Natural
   is (Natural (K))
   with
     Pre  => Is_Key_Size (K),
     Post => Key (Key_Size'Result) and then Key_Size'Result = Natural (K);
   --  The key size as the spec takes it, in the place of `{k}.
   --  @param K The key size Cryptol passed.
   --  @return K, a Natural with Key (K).

   function Round_Keys_Of (K : C_Size; W : All_Round_Keys) return Round_Keys
   is (W (0 .. Nr (Key_Size (K))))
   with
     Pre  => Is_Key_Size (K),
     Post => Is_Round_Keys (Key_Size (K), Round_Keys_Of'Result);
   --  The caller's [Nr k + 1]Block: the first Nr (K) + 1 blocks of W.
   --  @param K The key size Cryptol passed.
   --  @param W The C buffer.
   --  @return W (0 .. Nr (K)), a Round_Keys for K.

   function Key_Words_Of (K : C_Size; W : All_Key_Words) return Key_Words
   is (W (0 .. Nk (Key_Size (K)) - 1))
   with
     Pre  => Is_Key_Size (K),
     Post => Is_Key_Words (Key_Size (K), Key_Words_Of'Result);
   --  The caller's [Nk k]AESWord: the first Nk (K) words of W.
   --  @param K The key size Cryptol passed.
   --  @param W The C buffer.
   --  @return W (0 .. Nk (K) - 1), a Key_Words for K.

end Foundation_Spark.FFI.AES_Types;
