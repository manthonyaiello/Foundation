with Foundation_Spark.AES.Lemmas;

package body Foundation_Spark.AES.Impl with
  SPARK_Mode
is

   use type Interfaces.Unsigned_16;

   ---------
   -- Dot --
   ---------

   function Dot (B, C : Byte) return Byte is
      P : Interfaces.Unsigned_16 := 0;
      R : Byte := 0;
      T : Interfaces.Unsigned_16;
   begin
      for N in 1 .. 8 loop
         P := Interfaces.Shift_Left (P, 1)
              xor (Interfaces.Unsigned_16 (B)
                   and (0 - Interfaces.Unsigned_16
                              (Interfaces.Shift_Right (C, 8 - N) and 1)));
         pragma Loop_Invariant (P = Spec.GF28.Pmult_Fold (B, C, N));
      end loop;
      for N in 1 .. 15 loop
         T := Interfaces.Shift_Left (Interfaces.Unsigned_16 (R), 1)
              or (Interfaces.Shift_Right (P, 15 - N) and 1);
         R := Byte ((T xor (16#11B# and (0 - Interfaces.Shift_Right (T, 8))))
                    and 16#FF#);
         pragma Loop_Invariant
           (R = Spec.GF28.Pmod_Fold (P, Spec.GF28.M, N));
      end loop;
      return R;
   end Dot;

   ---------------------------
   -- The bitsliced S-box --
   ---------------------------

   --  The S-box without a table (issue #50). A table lookup reads the
   --  memory address S_Box'Address + B, so which cache line it touches
   --  depends on the secret byte B: the classic cache-timing leak of AES.
   --  Here the S-box is Boyar and Peralta's circuit of 128 gates (34 AND,
   --  94 XOR and XNOR) of depth 16 ("A small depth-16 circuit for the AES
   --  S-box", SEC 2012), whose every gate is a bitwise operation on a whole
   --  machine word: no branch, no index and no early exit depends on the
   --  data. It runs on eight bytes at once (SWAR): each byte keeps its own
   --  8-bit lane of a 64-bit word, its bit K extracted to the lane's bit 0
   --  by a shift and a mask, so one evaluation of the circuit computes
   --  eight S-box entries. The inverse S-box is InvSBox = A^-1 o SBox o
   --  A^-1, where A^-1 is the inverse of the S-box's affine map (FIPS-PUB-
   --  197 Section 5.3.2), as BearSSL's aes_ct does it.
   --
   --  The proof is gnatprove's: the postconditions of SBox_Lanes and
   --  Inv_SBox_Lanes state, lane by lane, equality with the spec's tables
   --  SBox.SBox and SBox.InvSBox, so Sub_Byte's and Inv_Sub_Byte's
   --  contracts, and everything proved above them, are unchanged.

   use type Interfaces.Unsigned_64;

   subtype Lanes is Interfaces.Unsigned_64;
   --  Eight bytes side by side, lane J in bits 8 * J .. 8 * J + 7.

   subtype Lane_Index is Natural range 0 .. 7;
   --  The lanes of a Lanes, and the bits of a byte.

   function Lane (X : Lanes; J : Lane_Index) return Byte
   is (Byte (Interfaces.Shift_Right (X, 8 * J) and 16#FF#));
   --  Lane J of X.
   --  @param X The lanes.
   --  @param J The lane.
   --  @return Bits 8 * J .. 8 * J + 7 of X, as a byte.

   Ones : constant Lanes := 16#0101_0101_0101_0101#;
   --  Bit 0 of every lane: the constant 1 of the circuit, in every lane.

   type Planes is array (Lane_Index) of Lanes;
   --  The bit planes of eight lanes: plane K holds, at bit 0 of lane J,
   --  bit K (the bit of value 2 ** K) of lane J, and zeros elsewhere.

   function To_Planes (X : Lanes) return Planes
   is ([for K in Lane_Index => Interfaces.Shift_Right (X, K) and Ones]);
   --  The bit planes of X.
   --  @param X The lanes.
   --  @return Its eight bit planes.

   function From_Planes (P : Planes) return Lanes
   is (P (0)
       or Interfaces.Shift_Left (P (1), 1)
       or Interfaces.Shift_Left (P (2), 2)
       or Interfaces.Shift_Left (P (3), 3)
       or Interfaces.Shift_Left (P (4), 4)
       or Interfaces.Shift_Left (P (5), 5)
       or Interfaces.Shift_Left (P (6), 6)
       or Interfaces.Shift_Left (P (7), 7));
   --  The lanes whose bit K is plane K's bit, the inverse of To_Planes on
   --  planes that keep to bit 0 of each lane.
   --  @param P The bit planes.
   --  @return The lanes.

   function Inv_Affine (P : Planes) return Planes
   is ([P (7) xor P (5) xor P (2) xor Ones,
        P (0) xor P (6) xor P (3),
        P (1) xor P (7) xor P (4) xor Ones,
        P (2) xor P (0) xor P (5),
        P (3) xor P (1) xor P (6),
        P (4) xor P (2) xor P (7),
        P (5) xor P (3) xor P (0),
        P (6) xor P (4) xor P (1)]);
   --  The inverse of the S-box's affine map [FIPS-PUB-197 Section 5.3.2],
   --  on bit planes: b'K = bK-1 ^ bK-3 ^ bK-6 ^ dK, indices mod 8, with
   --  d = 0x05 (the byte form is b <<< 1 ^ b <<< 3 ^ b <<< 6 ^ 0x05).
   --  @param P The bit planes of the input.
   --  @return The bit planes of the output.

   function Forward (P : Planes) return Planes
   is (declare
         U0 : constant Lanes := P (7);
         U1 : constant Lanes := P (6);
         U2 : constant Lanes := P (5);
         U3 : constant Lanes := P (4);
         U4 : constant Lanes := P (3);
         U5 : constant Lanes := P (2);
         U6 : constant Lanes := P (1);
         U7 : constant Lanes := P (0);
         T1 : constant Lanes := U0 xor U3;
         T2 : constant Lanes := U0 xor U5;
         T3 : constant Lanes := U0 xor U6;
         T4 : constant Lanes := U3 xor U5;
         T5 : constant Lanes := U4 xor U6;
         T6 : constant Lanes := T1 xor T5;
         T7 : constant Lanes := U1 xor U2;
         T8 : constant Lanes := U7 xor T6;
         T9 : constant Lanes := U7 xor T7;
         T10 : constant Lanes := T6 xor T7;
         T11 : constant Lanes := U1 xor U5;
         T12 : constant Lanes := U2 xor U5;
         T13 : constant Lanes := T3 xor T4;
         T14 : constant Lanes := T6 xor T11;
         T15 : constant Lanes := T5 xor T11;
         T16 : constant Lanes := T5 xor T12;
         T17 : constant Lanes := T9 xor T16;
         T18 : constant Lanes := U3 xor U7;
         T19 : constant Lanes := T7 xor T18;
         T20 : constant Lanes := T1 xor T19;
         T21 : constant Lanes := U6 xor U7;
         T22 : constant Lanes := T7 xor T21;
         T23 : constant Lanes := T2 xor T22;
         T24 : constant Lanes := T2 xor T10;
         T25 : constant Lanes := T20 xor T17;
         T26 : constant Lanes := T3 xor T16;
         T27 : constant Lanes := T1 xor T12;
         M1 : constant Lanes := T13 and T6;
         M2 : constant Lanes := T23 and T8;
         M3 : constant Lanes := T14 xor M1;
         M4 : constant Lanes := T19 and U7;
         M5 : constant Lanes := M4 xor M1;
         M6 : constant Lanes := T3 and T16;
         M7 : constant Lanes := T22 and T9;
         M8 : constant Lanes := T26 xor M6;
         M9 : constant Lanes := T20 and T17;
         M10 : constant Lanes := M9 xor M6;
         M11 : constant Lanes := T1 and T15;
         M12 : constant Lanes := T4 and T27;
         M13 : constant Lanes := M12 xor M11;
         M14 : constant Lanes := T2 and T10;
         M15 : constant Lanes := M14 xor M11;
         M16 : constant Lanes := M3 xor M2;
         M17 : constant Lanes := M5 xor T24;
         M18 : constant Lanes := M8 xor M7;
         M19 : constant Lanes := M10 xor M15;
         M20 : constant Lanes := M16 xor M13;
         M21 : constant Lanes := M17 xor M15;
         M22 : constant Lanes := M18 xor M13;
         M23 : constant Lanes := M19 xor T25;
         M24 : constant Lanes := M22 xor M23;
         M25 : constant Lanes := M22 and M20;
         M26 : constant Lanes := M21 xor M25;
         M27 : constant Lanes := M20 xor M21;
         M28 : constant Lanes := M23 xor M25;
         M29 : constant Lanes := M28 and M27;
         M30 : constant Lanes := M26 and M24;
         M31 : constant Lanes := M20 and M23;
         M32 : constant Lanes := M27 and M31;
         M33 : constant Lanes := M27 xor M25;
         M34 : constant Lanes := M21 and M22;
         M35 : constant Lanes := M24 and M34;
         M36 : constant Lanes := M24 xor M25;
         M37 : constant Lanes := M21 xor M29;
         M38 : constant Lanes := M32 xor M33;
         M39 : constant Lanes := M23 xor M30;
         M40 : constant Lanes := M35 xor M36;
         M41 : constant Lanes := M38 xor M40;
         M42 : constant Lanes := M37 xor M39;
         M43 : constant Lanes := M37 xor M38;
         M44 : constant Lanes := M39 xor M40;
         M45 : constant Lanes := M42 xor M41;
         M46 : constant Lanes := M44 and T6;
         M47 : constant Lanes := M40 and T8;
         M48 : constant Lanes := M39 and U7;
         M49 : constant Lanes := M43 and T16;
         M50 : constant Lanes := M38 and T9;
         M51 : constant Lanes := M37 and T17;
         M52 : constant Lanes := M42 and T15;
         M53 : constant Lanes := M45 and T27;
         M54 : constant Lanes := M41 and T10;
         M55 : constant Lanes := M44 and T13;
         M56 : constant Lanes := M40 and T23;
         M57 : constant Lanes := M39 and T19;
         M58 : constant Lanes := M43 and T3;
         M59 : constant Lanes := M38 and T22;
         M60 : constant Lanes := M37 and T20;
         M61 : constant Lanes := M42 and T1;
         M62 : constant Lanes := M45 and T4;
         M63 : constant Lanes := M41 and T2;
         L0 : constant Lanes := M61 xor M62;
         L1 : constant Lanes := M50 xor M56;
         L2 : constant Lanes := M46 xor M48;
         L3 : constant Lanes := M47 xor M55;
         L4 : constant Lanes := M54 xor M58;
         L5 : constant Lanes := M49 xor M61;
         L6 : constant Lanes := M62 xor L5;
         L7 : constant Lanes := M46 xor L3;
         L8 : constant Lanes := M51 xor M59;
         L9 : constant Lanes := M52 xor M53;
         L10 : constant Lanes := M53 xor L4;
         L11 : constant Lanes := M60 xor L2;
         L12 : constant Lanes := M48 xor M51;
         L13 : constant Lanes := M50 xor L0;
         L14 : constant Lanes := M52 xor M61;
         L15 : constant Lanes := M55 xor L1;
         L16 : constant Lanes := M56 xor L0;
         L17 : constant Lanes := M57 xor L1;
         L18 : constant Lanes := M58 xor L8;
         L19 : constant Lanes := M63 xor L4;
         L20 : constant Lanes := L0 xor L1;
         L21 : constant Lanes := L1 xor L7;
         L22 : constant Lanes := L3 xor L12;
         L23 : constant Lanes := L18 xor L2;
         L24 : constant Lanes := L15 xor L9;
         L25 : constant Lanes := L6 xor L10;
         L26 : constant Lanes := L7 xor L9;
         L27 : constant Lanes := L8 xor L10;
         L28 : constant Lanes := L11 xor L14;
         L29 : constant Lanes := L11 xor L17;
         S0 : constant Lanes := L6 xor L24;
         S1 : constant Lanes := L16 xor L26 xor Ones;
         S2 : constant Lanes := L19 xor L28 xor Ones;
         S3 : constant Lanes := L6 xor L21;
         S4 : constant Lanes := L20 xor L22;
         S5 : constant Lanes := L25 xor L29;
         S6 : constant Lanes := L13 xor L27 xor Ones;
         S7 : constant Lanes := L6 xor L23 xor Ones;
       begin
         [S7, S6, S5, S4, S3, S2, S1, S0]);
   --  Boyar and Peralta's depth-16 circuit, gate for gate under the paper's
   --  names: the top linear layer T1 .. T27 from the inputs U0 .. U7 (U0
   --  the most significant bit), the nonlinear middle M1 .. M63, the
   --  bottom linear layer L0 .. L29, and the outputs S0 .. S7 (S0 the most
   --  significant bit; S1, S2, S6 and S7 are XNORs, an XOR with Ones).
   --  @param P The bit planes of the input lanes.
   --  @return The bit planes of their S-box images.

   function SBox_Lanes (X : Lanes) return Lanes
   with
     Post =>
       (for all J in Lane_Index =>
          Lane (SBox_Lanes'Result, J) = Spec.SBox.SBox (Lane (X, J)));
   --  The S-box applied to each of the eight lanes of X.
   --  @param X The lanes.
   --  @return Lane J is SBox.cry's SBox @ (lane J of X).

   function SBox_Lanes (X : Lanes) return Lanes is
      R : constant Lanes := From_Planes (Forward (To_Planes (X)));
   begin
      pragma Assert (Lane (R, 0) = Spec.SBox.SBox (Lane (X, 0)));
      pragma Assert (Lane (R, 1) = Spec.SBox.SBox (Lane (X, 1)));
      pragma Assert (Lane (R, 2) = Spec.SBox.SBox (Lane (X, 2)));
      pragma Assert (Lane (R, 3) = Spec.SBox.SBox (Lane (X, 3)));
      pragma Assert (Lane (R, 4) = Spec.SBox.SBox (Lane (X, 4)));
      pragma Assert (Lane (R, 5) = Spec.SBox.SBox (Lane (X, 5)));
      pragma Assert (Lane (R, 6) = Spec.SBox.SBox (Lane (X, 6)));
      pragma Assert (Lane (R, 7) = Spec.SBox.SBox (Lane (X, 7)));
      return R;
   end SBox_Lanes;

   function Inv_SBox_Lanes (X : Lanes) return Lanes
   with
     Post =>
       (for all J in Lane_Index =>
          Lane (Inv_SBox_Lanes'Result, J) = Spec.SBox.InvSBox (Lane (X, J)));
   --  The inverse S-box applied to each of the eight lanes of X.
   --  @param X The lanes.
   --  @return Lane J is SBox.cry's InvSBox @ (lane J of X).

   function Inv_SBox_Lanes (X : Lanes) return Lanes is
      R : constant Lanes :=
        From_Planes (Inv_Affine (Forward (Inv_Affine (To_Planes (X)))));
   begin
      pragma Assert (Lane (R, 0) = Spec.SBox.InvSBox (Lane (X, 0)));
      pragma Assert (Lane (R, 1) = Spec.SBox.InvSBox (Lane (X, 1)));
      pragma Assert (Lane (R, 2) = Spec.SBox.InvSBox (Lane (X, 2)));
      pragma Assert (Lane (R, 3) = Spec.SBox.InvSBox (Lane (X, 3)));
      pragma Assert (Lane (R, 4) = Spec.SBox.InvSBox (Lane (X, 4)));
      pragma Assert (Lane (R, 5) = Spec.SBox.InvSBox (Lane (X, 5)));
      pragma Assert (Lane (R, 6) = Spec.SBox.InvSBox (Lane (X, 6)));
      pragma Assert (Lane (R, 7) = Spec.SBox.InvSBox (Lane (X, 7)));
      return R;
   end Inv_SBox_Lanes;

   function Pack (S : Block; F : Block_Index) return Lanes
   is (Lanes (S (F))
       or Interfaces.Shift_Left (Lanes (S (F + 1)), 8)
       or Interfaces.Shift_Left (Lanes (S (F + 2)), 16)
       or Interfaces.Shift_Left (Lanes (S (F + 3)), 24)
       or Interfaces.Shift_Left (Lanes (S (F + 4)), 32)
       or Interfaces.Shift_Left (Lanes (S (F + 5)), 40)
       or Interfaces.Shift_Left (Lanes (S (F + 6)), 48)
       or Interfaces.Shift_Left (Lanes (S (F + 7)), 56))
   with
     Pre  => F in 0 | 8,
     Post => (for all J in Lane_Index => Lane (Pack'Result, J) = S (F + J));
   --  Eight bytes of a block as lanes.
   --  @param S The block.
   --  @param F The first byte: 0 or 8.
   --  @return Lane J is S (F + J).

   --------------
   -- Sub_Byte --
   --------------

   function Sub_Byte (B : Byte) return Byte is
      R : constant Lanes := SBox_Lanes (Lanes (B));
   begin
      pragma Assert (Lane (Lanes (B), 0) = B);
      return Lane (R, 0);
   end Sub_Byte;

   --------------
   -- Sub_Word --
   --------------

   function Sub_Word (A : AESWord) return AESWord is
      X : constant Lanes :=
        Lanes (A (0))
        or Interfaces.Shift_Left (Lanes (A (1)), 8)
        or Interfaces.Shift_Left (Lanes (A (2)), 16)
        or Interfaces.Shift_Left (Lanes (A (3)), 24);
      R : constant Lanes := SBox_Lanes (X);
   begin
      pragma Assert
        (Lane (X, 0) = A (0) and then Lane (X, 1) = A (1)
         and then Lane (X, 2) = A (2) and then Lane (X, 3) = A (3));
      return [Lane (R, 0), Lane (R, 1), Lane (R, 2), Lane (R, 3)];
   end Sub_Word;

   ------------------
   -- Inv_Sub_Byte --
   ------------------

   function Inv_Sub_Byte (B : Byte) return Byte is
      R : constant Lanes := Inv_SBox_Lanes (Lanes (B));
   begin
      pragma Assert (Lane (Lanes (B), 0) = B);
      return Lane (R, 0);
   end Inv_Sub_Byte;

   ----------------
   -- Expand_Key --
   ----------------

   procedure Expand_Key (K : Key_Size; Key : Key_Words; W : out Round_Keys) is

      subtype Word_Index is Natural range 0 .. 4 * (Max_Nr + 1) - 1;
      --  The indices of the expanded key's words, for the largest key.

      type Word_Schedule is array (Word_Index) of AESWord;
      --  The expanded key as words: KeyExpansion.cry's w.

      Nk_K : constant Positive := Nk (K);
      Ws   : Word_Schedule := [others => [others => 0]];
      Temp : AESWord;

   begin
      for I in 0 .. 4 * (Nr (K) + 1) - 1 loop
         Spec.Dispatch.Lemma_W (K, Key, I);
         if I < Nk_K then
            Temp := Key (I);
            pragma Assert (Temp = Spec.Dispatch.W (K, Key, I));
         else
            pragma Assert (Ws (I - 1) = Spec.Dispatch.W (K, Key, I - 1));
            pragma Assert
              (Ws (I - Nk_K) = Spec.Dispatch.W (K, Key, I - Nk_K));
            if I mod Nk_K = 0 then
               Temp :=
                 Xor_Word
                   (Xor_Word
                      (Ws (I - Nk_K), Sub_Word (Rot_Word (Ws (I - 1)))),
                    Rcon (I / Nk_K));
               pragma Assert (Temp = Spec.Dispatch.W (K, Key, I));
            elsif I mod Nk_K = 4 and then Nk_K > 6 then
               Temp := Xor_Word (Ws (I - Nk_K), Sub_Word (Ws (I - 1)));
               pragma Assert (Temp = Spec.Dispatch.W (K, Key, I));
            else
               Temp := Xor_Word (Ws (I - Nk_K), Ws (I - 1));
               pragma Assert (Temp = Spec.Dispatch.W (K, Key, I));
            end if;
         end if;
         pragma Assert (Temp = Spec.Dispatch.W (K, Key, I));
         Ws (I) := Temp;
         pragma Loop_Invariant
           (for all J in 0 .. I => Ws (J) = Spec.Dispatch.W (K, Key, J));
      end loop;

      W := [others => [others => 0]];
      for R in W'Range loop
         W (R) := [for I in Block_Index => Ws (4 * R + I / 4) (I mod 4)];
         pragma Loop_Invariant
           (for all Q in W'First .. R =>
              W (Q) = Spec.Dispatch.KeyExpansion (K, Key) (Q));
      end loop;
   end Expand_Key;

   ---------------
   -- Sub_Bytes --
   ---------------

   procedure Sub_Bytes (State : in out Block) is
      Lo : constant Lanes := SBox_Lanes (Pack (State, 0));
      Hi : constant Lanes := SBox_Lanes (Pack (State, 8));
   begin
      pragma Assert
        (for all J in Lane_Index =>
           Lane (Lo, J) = Spec.SBox.SBox (State (J)));
      pragma Assert
        (for all J in Lane_Index =>
           Lane (Hi, J) = Spec.SBox.SBox (State (8 + J)));
      State :=
        [Lane (Lo, 0), Lane (Lo, 1), Lane (Lo, 2), Lane (Lo, 3),
         Lane (Lo, 4), Lane (Lo, 5), Lane (Lo, 6), Lane (Lo, 7),
         Lane (Hi, 0), Lane (Hi, 1), Lane (Hi, 2), Lane (Hi, 3),
         Lane (Hi, 4), Lane (Hi, 5), Lane (Hi, 6), Lane (Hi, 7)];
   end Sub_Bytes;

   -------------------
   -- Inv_Sub_Bytes --
   -------------------

   procedure Inv_Sub_Bytes (State : in out Block) is
      Lo : constant Lanes := Inv_SBox_Lanes (Pack (State, 0));
      Hi : constant Lanes := Inv_SBox_Lanes (Pack (State, 8));
   begin
      pragma Assert
        (for all J in Lane_Index =>
           Lane (Lo, J) = Spec.SBox.InvSBox (State (J)));
      pragma Assert
        (for all J in Lane_Index =>
           Lane (Hi, J) = Spec.SBox.InvSBox (State (8 + J)));
      State :=
        [Lane (Lo, 0), Lane (Lo, 1), Lane (Lo, 2), Lane (Lo, 3),
         Lane (Lo, 4), Lane (Lo, 5), Lane (Lo, 6), Lane (Lo, 7),
         Lane (Hi, 0), Lane (Hi, 1), Lane (Hi, 2), Lane (Hi, 3),
         Lane (Hi, 4), Lane (Hi, 5), Lane (Hi, 6), Lane (Hi, 7)];
   end Inv_Sub_Bytes;

   ----------------
   -- Shift_Rows --
   ----------------

   procedure Shift_Rows (State : in out Block) is
   begin
      State :=
        [State (0), State (5), State (10), State (15),
         State (4), State (9), State (14), State (3),
         State (8), State (13), State (2), State (7),
         State (12), State (1), State (6), State (11)];
   end Shift_Rows;

   --------------------
   -- Inv_Shift_Rows --
   --------------------

   procedure Inv_Shift_Rows (State : in out Block) is
   begin
      State :=
        [State (0), State (13), State (10), State (7),
         State (4), State (1), State (14), State (11),
         State (8), State (5), State (2), State (15),
         State (12), State (9), State (6), State (3)];
   end Inv_Shift_Rows;

   ----------------
   -- Mix_Column --
   ----------------

   function Mix_Column (S : AESWord) return AESWord is
      X : constant AESWord :=
        [X_Times (S (0)), X_Times (S (1)), X_Times (S (2)), X_Times (S (3))];
   begin
      for I in AESWord_Index loop
         Lemmas.Lemma_Dot (16#02#, S (I));
         Lemmas.Lemma_Dot (16#03#, S (I));
         pragma Loop_Invariant
           (for all J in 0 .. I =>
              Spec.GF28.Dot (16#02#, S (J)) = X (J)
              and then Spec.GF28.Dot (16#03#, S (J)) = (X (J) xor S (J)));
      end loop;
      return
        [X (0) xor (X (1) xor S (1)) xor S (2) xor S (3),
         S (0) xor X (1) xor (X (2) xor S (2)) xor S (3),
         S (0) xor S (1) xor X (2) xor (X (3) xor S (3)),
         (X (0) xor S (0)) xor S (1) xor S (2) xor X (3)];
   end Mix_Column;

   --------------------
   -- Inv_Mix_Column --
   --------------------

   function Inv_Mix_Byte (A, B, C, D : Byte) return Byte
   with
     Post => Inv_Mix_Byte'Result
             = (Spec.GF28.Dot (16#0e#, A) xor Spec.GF28.Dot (16#0b#, B)
                xor Spec.GF28.Dot (16#0d#, C) xor Spec.GF28.Dot (16#09#, D));
   --  One byte of InvMixColumnsStep: 0x0e • A ^ 0x0b • B ^ 0x0d • C ^
   --  0x09 • D, with X_Times alone. Inv_Mix_Column calls it once per row,
   --  rotating the column, so that each proof has four products in it.
   --  @param A The byte multiplied by 0x0e.
   --  @param B The byte multiplied by 0x0b.
   --  @param C The byte multiplied by 0x0d.
   --  @param D The byte multiplied by 0x09.
   --  @return The mixed byte.

   function Inv_Mix_Byte (A, B, C, D : Byte) return Byte is
      A2 : constant Byte := X_Times (A);
      A4 : constant Byte := X_Times (A2);
      B2 : constant Byte := X_Times (B);
      B4 : constant Byte := X_Times (B2);
      C2 : constant Byte := X_Times (C);
      C4 : constant Byte := X_Times (C2);
      D2 : constant Byte := X_Times (D);
      D4 : constant Byte := X_Times (D2);
   begin
      Lemmas.Lemma_Dot (16#0e#, A);
      Lemmas.Lemma_Dot (16#0b#, B);
      Lemmas.Lemma_Dot (16#0d#, C);
      Lemmas.Lemma_Dot (16#09#, D);
      return (X_Times (A4) xor A4 xor A2)
             xor (X_Times (B4) xor B2 xor B)
             xor (X_Times (C4) xor C4 xor C)
             xor (X_Times (D4) xor D);
   end Inv_Mix_Byte;

   function Inv_Mix_Column (S : AESWord) return AESWord is
   begin
      return
        [Inv_Mix_Byte (S (0), S (1), S (2), S (3)),
         Inv_Mix_Byte (S (1), S (2), S (3), S (0)),
         Inv_Mix_Byte (S (2), S (3), S (0), S (1)),
         Inv_Mix_Byte (S (3), S (0), S (1), S (2))];
   end Inv_Mix_Column;

   -----------------
   -- Mix_Columns --
   -----------------

   procedure Mix_Columns (State : in out Block) is
      Cols  : constant Columns := Split (State);
      Mixed : constant Columns :=
        [Mix_Column (Cols (0)), Mix_Column (Cols (1)),
         Mix_Column (Cols (2)), Mix_Column (Cols (3))];
      Expected : constant Columns :=
        [for J in AESWord_Index =>
           Spec.Cipher.MixColumnsStep (Split (State) (J))]
      with Ghost;
   begin
      pragma Assert
        (for all J in AESWord_Index =>
           Mixed (J) = Spec.Cipher.MixColumnsStep (Split (State) (J)));
      pragma Assert (Mixed = Expected);
      State := Join (Mixed);
      pragma Assert (State = Join (Expected));
   end Mix_Columns;

   ---------------------
   -- Inv_Mix_Columns --
   ---------------------

   procedure Inv_Mix_Columns (State : in out Block) is
      Cols  : constant Columns := Split (State);
      Mixed : constant Columns :=
        [Inv_Mix_Column (Cols (0)), Inv_Mix_Column (Cols (1)),
         Inv_Mix_Column (Cols (2)), Inv_Mix_Column (Cols (3))];
      Expected : constant Columns :=
        [for J in AESWord_Index =>
           Spec.Cipher.InvMixColumnsStep (Split (State) (J))]
      with Ghost;
   begin
      pragma Assert
        (for all J in AESWord_Index =>
           Mixed (J) = Spec.Cipher.InvMixColumnsStep (Split (State) (J)));
      pragma Assert (Mixed = Expected);
      State := Join (Mixed);
      pragma Assert (State = Join (Expected));
   end Inv_Mix_Columns;

   -------------------
   -- Add_Round_Key --
   -------------------

   procedure Add_Round_Key (State : in out Block; Key : Block) is
   begin
      State := [for I in Block_Index => State (I) xor Key (I)];
   end Add_Round_Key;

   -----------
   -- Round --
   -----------

   procedure Round (State : in out Block; Key : Block) is
      Old : constant Block := State
      with Ghost;
   begin
      Sub_Bytes (State);
      Shift_Rows (State);
      pragma Assert
        (State = Spec.Cipher.ShiftRows (Spec.Cipher.SubBytes (Old)));
      Lemmas.Lemma_MixColumns_Eq
        (State, Spec.Cipher.ShiftRows (Spec.Cipher.SubBytes (Old)));
      Mix_Columns (State);
      Add_Round_Key (State, Key);
   end Round;

   ---------------
   -- Inv_Round --
   ---------------

   procedure Inv_Round (State : in out Block; Key : Block) is
      Old : constant Block := State
      with Ghost;
   begin
      Inv_Shift_Rows (State);
      Inv_Sub_Bytes (State);
      Add_Round_Key (State, Key);
      pragma Assert
        (State
         = Spec.Cipher.AddRoundKey
             (Spec.Cipher.InvSubBytes (Spec.Cipher.InvShiftRows (Old)), Key));
      Lemmas.Lemma_InvMixColumns_Eq
        (State,
         Spec.Cipher.AddRoundKey
           (Spec.Cipher.InvSubBytes (Spec.Cipher.InvShiftRows (Old)), Key));
      Inv_Mix_Columns (State);
   end Inv_Round;

   ---------------------
   -- Inv_Round_Prime --
   ---------------------

   procedure Inv_Round_Prime (State : in out Block; Key : Block) is
      Old : constant Block := State
      with Ghost;
   begin
      Add_Round_Key (State, Key);
      Lemmas.Lemma_InvMixColumns_Eq
        (State, Spec.Cipher.AddRoundKey (Old, Key));
      Inv_Mix_Columns (State);
      Inv_Shift_Rows (State);
      Inv_Sub_Bytes (State);
   end Inv_Round_Prime;

   -------------------
   -- Encrypt_Block --
   -------------------

   procedure Encrypt_Block (K : Key_Size; W : Round_Keys; State : in out Block)
   is
      S0 : constant Block := Spec.Cipher.AddRoundKey (State, W (0))
      with Ghost;
   begin
      Add_Round_Key (State, W (0));
      for R in 1 .. Nr (K) - 1 loop
         pragma Loop_Invariant
           (State = Spec.Cipher.Foldl_Round (S0, W (1 .. R - 1)));
         Lemmas.Lemma_Round_Eq
           (State, Spec.Cipher.Foldl_Round (S0, W (1 .. R - 1)), W (R));
         Lemmas.Lemma_Foldl_Round_Snoc (S0, W (1 .. R));
         Round (State, W (R));
      end loop;
      pragma Assert
        (State = Spec.Cipher.Foldl_Round (S0, W (1 .. Nr (K) - 1)));
      Sub_Bytes (State);
      Shift_Rows (State);
      Add_Round_Key (State, W (Nr (K)));
   end Encrypt_Block;

   -------------------
   -- Decrypt_Block --
   -------------------

   procedure Decrypt_Block (K : Key_Size; W : Round_Keys; State : in out Block)
   is
      S0 : constant Block := Spec.Cipher.AddRoundKey (State, W (Nr (K)))
      with Ghost;
      RK : constant Round_Keys :=
        Spec.Cipher.Reverse_Keys (W (1 .. Nr (K) - 1))
      with Ghost;
   begin
      Add_Round_Key (State, W (Nr (K)));
      for J in 1 .. Nr (K) - 1 loop
         pragma Loop_Invariant
           (State = Spec.Cipher.Foldl_InvRound (S0, RK (1 .. J - 1)));
         pragma Assert (RK (J) = W (Nr (K) - J));
         Lemmas.Lemma_InvRound_Eq
           (State, Spec.Cipher.Foldl_InvRound (S0, RK (1 .. J - 1)),
            W (Nr (K) - J));
         Lemmas.Lemma_Foldl_InvRound_Snoc (S0, RK (1 .. J));
         Inv_Round (State, W (Nr (K) - J));
      end loop;
      pragma Assert (State = Spec.Cipher.Foldl_InvRound (S0, RK));
      Inv_Shift_Rows (State);
      Inv_Sub_Bytes (State);
      Add_Round_Key (State, W (0));
   end Decrypt_Block;

   -------------------------
   -- Decrypt_Block_Prime --
   -------------------------

   procedure Decrypt_Block_Prime
     (K : Key_Size; W : Round_Keys; State : in out Block)
   is
      S0 : constant Block :=
        Spec.Cipher.InvSubBytes
          (Spec.Cipher.InvShiftRows
             (Spec.Cipher.AddRoundKey (State, W (Nr (K)))))
      with Ghost;
      RK : constant Round_Keys :=
        Spec.Cipher.Reverse_Keys (W (1 .. Nr (K) - 1))
      with Ghost;
   begin
      Add_Round_Key (State, W (Nr (K)));
      Inv_Shift_Rows (State);
      Inv_Sub_Bytes (State);
      for J in 1 .. Nr (K) - 1 loop
         pragma Loop_Invariant
           (State = Spec.Cipher.Foldl_InvRound_Prime (S0, RK (1 .. J - 1)));
         pragma Assert (RK (J) = W (Nr (K) - J));
         Lemmas.Lemma_InvRound_Prime_Eq
           (State, Spec.Cipher.Foldl_InvRound_Prime (S0, RK (1 .. J - 1)),
            W (Nr (K) - J));
         Lemmas.Lemma_Foldl_InvRound_Prime_Snoc (S0, RK (1 .. J));
         Inv_Round_Prime (State, W (Nr (K) - J));
      end loop;
      pragma Assert (State = Spec.Cipher.Foldl_InvRound_Prime (S0, RK));
      Add_Round_Key (State, W (0));
   end Decrypt_Block_Prime;

end Foundation_Spark.AES.Impl;
