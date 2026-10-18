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
              xor (if (Interfaces.Shift_Right (C, 8 - N) and 1) = 1
                   then Interfaces.Unsigned_16 (B) else 0);
         pragma Loop_Invariant (P = Spec.GF28.Pmult_Fold (B, C, N));
      end loop;
      for N in 1 .. 15 loop
         T := Interfaces.Shift_Left (Interfaces.Unsigned_16 (R), 1)
              or (Interfaces.Shift_Right (P, 15 - N) and 1);
         R := (if T >= 256 then Byte (T xor 16#11B#) else Byte (T));
         pragma Loop_Invariant
           (R = Spec.GF28.Pmod_Fold (P, Spec.GF28.M, N));
      end loop;
      return R;
   end Dot;

   --------------
   -- Sub_Byte --
   --------------

   function Sub_Byte (B : Byte) return Byte is
   begin
      return S_Box (B);
   end Sub_Byte;

   ------------------
   -- Inv_Sub_Byte --
   ------------------

   function Inv_Sub_Byte (B : Byte) return Byte is
   begin
      return Inv_S_Box (B);
   end Inv_Sub_Byte;

   ----------------
   -- Expand_Key --
   ----------------

   procedure Expand_Key (K : Natural; Key : Key_Words; W : out Round_Keys) is

      subtype Word_Index is Natural range 0 .. 4 * (Max_Nr + 1) - 1;
      --  The indices of the expanded key's words, for the largest key.

      type Word_Schedule is array (Word_Index) of AESWord;
      --  The expanded key as words: KeyExpansion.cry's w.

      Nk_K : constant Positive := Nk (K);
      Ws   : Word_Schedule := [others => [others => 0]];
      Temp : AESWord;

   begin
      for I in 0 .. 4 * (Nr (K) + 1) - 1 loop
         if I < Nk_K then
            Temp := Key (I);
            pragma Assert (Temp = Spec.KeyExpansion.W (K, Key, I));
         else
            pragma Assert (Ws (I - 1) = Spec.KeyExpansion.W (K, Key, I - 1));
            pragma Assert
              (Ws (I - Nk_K) = Spec.KeyExpansion.W (K, Key, I - Nk_K));
            if I mod Nk_K = 0 then
               Temp :=
                 Xor_Word
                   (Xor_Word
                      (Ws (I - Nk_K), Sub_Word (Rot_Word (Ws (I - 1)))),
                    Rcon (I / Nk_K));
               pragma Assert (Temp = Spec.KeyExpansion.W (K, Key, I));
            elsif I mod Nk_K = 4 and then Nk_K > 6 then
               Temp := Xor_Word (Ws (I - Nk_K), Sub_Word (Ws (I - 1)));
               pragma Assert (Temp = Spec.KeyExpansion.W (K, Key, I));
            else
               Temp := Xor_Word (Ws (I - Nk_K), Ws (I - 1));
               pragma Assert (Temp = Spec.KeyExpansion.W (K, Key, I));
            end if;
         end if;
         pragma Assert (Temp = Spec.KeyExpansion.W (K, Key, I));
         Ws (I) := Temp;
         pragma Loop_Invariant
           (for all J in 0 .. I => Ws (J) = Spec.KeyExpansion.W (K, Key, J));
      end loop;

      W := [others => [others => 0]];
      for R in W'Range loop
         W (R) := [for I in Block_Index => Ws (4 * R + I / 4) (I mod 4)];
         pragma Loop_Invariant
           (for all Q in W'First .. R =>
              W (Q) = Spec.KeyExpansion.KeyExpansion (K, Key) (Q));
      end loop;
   end Expand_Key;

   ---------------
   -- Sub_Bytes --
   ---------------

   procedure Sub_Bytes (State : in out Block) is
   begin
      State := [for I in Block_Index => Sub_Byte (State (I))];
   end Sub_Bytes;

   -------------------
   -- Inv_Sub_Bytes --
   -------------------

   procedure Inv_Sub_Bytes (State : in out Block) is
   begin
      State := [for I in Block_Index => Inv_Sub_Byte (State (I))];
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

   function Inv_Mix_Column (S : AESWord) return AESWord is
      X2 : constant AESWord :=
        [X_Times (S (0)), X_Times (S (1)), X_Times (S (2)), X_Times (S (3))];
      X4 : constant AESWord :=
        [X_Times (X2 (0)), X_Times (X2 (1)), X_Times (X2 (2)),
         X_Times (X2 (3))];
      X8 : constant AESWord :=
        [X_Times (X4 (0)), X_Times (X4 (1)), X_Times (X4 (2)),
         X_Times (X4 (3))];
      M9  : constant AESWord := Xor_Word (X8, S);
      M11 : constant AESWord := Xor_Word (Xor_Word (X8, X2), S);
      M13 : constant AESWord := Xor_Word (Xor_Word (X8, X4), S);
      M14 : constant AESWord := Xor_Word (Xor_Word (X8, X4), X2);
   begin
      for I in AESWord_Index loop
         Lemmas.Lemma_Dot (16#09#, S (I));
         Lemmas.Lemma_Dot (16#0b#, S (I));
         Lemmas.Lemma_Dot (16#0d#, S (I));
         Lemmas.Lemma_Dot (16#0e#, S (I));
         pragma Loop_Invariant
           (for all J in 0 .. I =>
              Spec.GF28.Dot (16#09#, S (J)) = M9 (J)
              and then Spec.GF28.Dot (16#0b#, S (J)) = M11 (J)
              and then Spec.GF28.Dot (16#0d#, S (J)) = M13 (J)
              and then Spec.GF28.Dot (16#0e#, S (J)) = M14 (J));
      end loop;
      return
        [M14 (0) xor M11 (1) xor M13 (2) xor M9 (3),
         M9 (0) xor M14 (1) xor M11 (2) xor M13 (3),
         M13 (0) xor M9 (1) xor M14 (2) xor M11 (3),
         M11 (0) xor M13 (1) xor M9 (2) xor M14 (3)];
   end Inv_Mix_Column;

   -----------------
   -- Mix_Columns --
   -----------------

   procedure Mix_Columns (State : in out Block) is
      Cols  : constant Columns := Split (State);
      Mixed : constant Columns :=
        [Mix_Column (Cols (0)), Mix_Column (Cols (1)),
         Mix_Column (Cols (2)), Mix_Column (Cols (3))];
   begin
      pragma Assert
        (for all J in AESWord_Index =>
           Mixed (J) = Spec.Cipher.MixColumnsStep (Split (State) (J)));
      State := Join (Mixed);
   end Mix_Columns;

   ---------------------
   -- Inv_Mix_Columns --
   ---------------------

   procedure Inv_Mix_Columns (State : in out Block) is
      Cols  : constant Columns := Split (State);
      Mixed : constant Columns :=
        [Inv_Mix_Column (Cols (0)), Inv_Mix_Column (Cols (1)),
         Inv_Mix_Column (Cols (2)), Inv_Mix_Column (Cols (3))];
   begin
      pragma Assert
        (for all J in AESWord_Index =>
           Mixed (J) = Spec.Cipher.InvMixColumnsStep (Split (State) (J)));
      State := Join (Mixed);
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

   procedure Encrypt_Block (K : Natural; W : Round_Keys; State : in out Block)
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

   procedure Decrypt_Block (K : Natural; W : Round_Keys; State : in out Block)
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
     (K : Natural; W : Round_Keys; State : in out Block)
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
