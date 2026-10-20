with Foundation_Spark.AES.Main_Lemmas;
with Foundation_Spark.AES.Spec.Cipher;
with Foundation_Spark.AES.Spec.Dispatch;
with Foundation_Spark.AES.Spec.Properties;

package body Foundation_Spark.AES.Impl.Main with
  SPARK_Mode
is

   ------------------
   -- Key_Words_Of --
   ------------------

   function Key_Words_Of (K : Natural; Key : Key_Bytes) return Key_Words is
      Ws : Key_Words (0 .. Nk (K) - 1) := [others => [others => 0]];
   begin
      for J in Ws'Range loop
         Ws (J) := [Key (4 * J), Key (4 * J + 1), Key (4 * J + 2),
                    Key (4 * J + 3)];
         pragma Loop_Invariant
           (for all J2 in 0 .. J =>
              (for all I in AESWord_Index => Ws (J2) (I) = Key (4 * J2 + I)));
      end loop;
      return Ws;
   end Key_Words_Of;

   -------------
   -- Encrypt --
   -------------

   function Encrypt (K : Natural; Key : Key_Bytes; Input : Block)
     return Block
   is
      Ws    : constant Key_Words := Key_Words_Of (K, Key);
      W     : Round_Keys (0 .. Nr (K));
      State : Block := Input;
   begin
      Expand_Key (K, Ws, W);
      Encrypt_Block (K, W, State);

      --  The spec's Encrypt applies KeyExpansion to split (split key) and
      --  Cipher to split in: equal to Ws and Input, but other objects.
      AES.Main_Lemmas.Lemma_Split_Join_Key (K, Key);
      pragma Assert (Ws = Spec.Main.Split_Key (K, Join_Key (Key)));
      AES.Main_Lemmas.Lemma_KeyExpansion_Eq
        (K, Ws, Spec.Main.Split_Key (K, Join_Key (Key)));
      Spec.Properties.Lemma_Split_Join_Block (Input);
      AES.Main_Lemmas.Lemma_Cipher_Eq
        (K,
         W,
         Spec.Dispatch.KeyExpansion
           (K, Spec.Main.Split_Key (K, Join_Key (Key))),
         Input,
         Spec.Main.Split_Block (Spec.Main.Join_Block (Input)));
      pragma Assert
        (State
         = Spec.Dispatch.Cipher
             (K,
              Spec.Dispatch.KeyExpansion
                (K, Spec.Main.Split_Key (K, Join_Key (Key))),
              Spec.Main.Split_Block (Spec.Main.Join_Block (Input))));
      return State;
   end Encrypt;

   -------------
   -- Decrypt --
   -------------

   function Decrypt (K : Natural; Key : Key_Bytes; Input : Block)
     return Block
   is
      Ws    : constant Key_Words := Key_Words_Of (K, Key);
      W     : Round_Keys (0 .. Nr (K));
      State : Block := Input;
   begin
      Expand_Key (K, Ws, W);
      Decrypt_Block (K, W, State);

      --  As in Encrypt, with InvCipher.
      AES.Main_Lemmas.Lemma_Split_Join_Key (K, Key);
      pragma Assert (Ws = Spec.Main.Split_Key (K, Join_Key (Key)));
      AES.Main_Lemmas.Lemma_KeyExpansion_Eq
        (K, Ws, Spec.Main.Split_Key (K, Join_Key (Key)));
      Spec.Properties.Lemma_Split_Join_Block (Input);
      AES.Main_Lemmas.Lemma_InvCipher_Eq
        (K,
         W,
         Spec.Dispatch.KeyExpansion
           (K, Spec.Main.Split_Key (K, Join_Key (Key))),
         Input,
         Spec.Main.Split_Block (Spec.Main.Join_Block (Input)));
      pragma Assert
        (State
         = Spec.Cipher.InvCipher
             (K,
              Spec.Dispatch.KeyExpansion
                (K, Spec.Main.Split_Key (K, Join_Key (Key))),
              Spec.Main.Split_Block (Spec.Main.Join_Block (Input))));
      return State;
   end Decrypt;

end Foundation_Spark.AES.Impl.Main;
