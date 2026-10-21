--  A ctgrind-style test (issue #50), after Adam Langley's ctgrind: the
--  secrets (an AES key and block, a SHA-256 message, an HMAC key and text,
--  the operands of Dot) are marked undefined for Valgrind's Memcheck, and
--  the release-built code runs on them. Memcheck then reports every
--  conditional branch ("Conditional jump or move depends on uninitialised
--  value(s)") and every memory address ("Use of uninitialised value of size
--  8") computed from a secret. The results are marked defined again before
--  they are printed, so printing them is not reported.
--
--  Usage (under Valgrind; outside it, the requests do nothing):
--    valgrind --error-exitcode=1 obj/ct/ct_grind           must report 0 errors
--    valgrind obj/ct/ct_grind control                      must report the
--      control: one table lookup indexed by a secret byte, in this file,
--      which shows that the marking works
--
--  Lengths, the key size and loop bounds are public and stay defined.

with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces;
with System;
with CT_Valgrind;
with Foundation_Spark.AES.Impl;
with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.HMAC.SHA256_Impl;
with Foundation_Spark.SHA2.SHA256_Bytes;
with Foundation_Spark.SHA2.SHA256_Stream;

procedure CT_Grind is

   use Interfaces;
   use Foundation_Spark.AES.Spec.Types;

   package Impl renames Foundation_Spark.AES.Impl;
   package SB renames Foundation_Spark.SHA2.SHA256_Bytes;
   use type SB.Byte_Index;

   procedure Secret (X : System.Address; Len : Natural)
     renames CT_Valgrind.Make_Undefined;
   --  Mark Len bytes from X secret.

   procedure Public (X : System.Address; Len : Natural)
     renames CT_Valgrind.Make_Defined;
   --  Mark Len bytes from X public again.

   type Sizes is array (1 .. 3) of Key_Size;
   --  The key sizes to run.

   Sum : Unsigned_8 := 0;
   --  Folded from every (public again) result, and printed.

   procedure Fold (X : Unsigned_8);
   --  Fold a public byte into Sum.
   --  @param X The byte.

   procedure Fold (X : Unsigned_8) is
   begin
      Sum := Sum xor X;
   end Fold;

begin
   if Ada.Command_Line.Argument_Count >= 1
     and then Ada.Command_Line.Argument (1) = "control"
   then
      --  The control: a table lookup indexed by a secret byte.
      declare
         Table : constant array (Unsigned_8) of Unsigned_8 :=
           [for I in Unsigned_8 => I * 7];
         S     : Unsigned_8 := 16#53#;
         R     : Unsigned_8;
      begin
         Secret (S'Address, 1);
         R := Table (S);
         Public (R'Address, 1);
         Fold (R);
      end;
   end if;

   for K of Sizes'[128, 192, 256] loop
      declare
         Key : Key_Words (0 .. Nk (K) - 1) :=
           [for I in 0 .. Nk (K) - 1 =>
              [for J in AESWord_Index => Byte ((7 * I + J) mod 256)]];
         W   : Round_Keys (0 .. Nr (K));
         S   : Block := [for I in Block_Index => Byte (I * 17 mod 256)];
         D   : Block;
      begin
         Secret (Key'Address, Key'Length * 4);
         Secret (S'Address, 16);
         Impl.Expand_Key (K, Key, W);
         Impl.Encrypt_Block (K, W, S);
         D := S;
         Impl.Decrypt_Block (K, W, D);
         Impl.Decrypt_Block_Prime (K, W, S);
         Public (S'Address, 16);
         Public (D'Address, 16);
         Fold (S (0));
         Fold (D (0));
      end;
   end loop;

   declare
      B, C, R : Unsigned_8;
   begin
      B := 16#57#;
      C := 16#83#;
      Secret (B'Address, 1);
      Secret (C'Address, 1);
      R := Impl.Dot (B, C) xor Impl.X_Times (B) xor Impl.Sub_Byte (C)
           xor Impl.Inv_Sub_Byte (B);
      Public (R'Address, 1);
      Fold (R);
   end;

   declare
      M : SB.Byte_Array (0 .. 99) :=
        [for I in SB.Byte_Index range 0 .. 99 => Unsigned_8 (I)];
      D : SB.Digest;
   begin
      Secret (M'Address, M'Length);
      D := Foundation_Spark.SHA2.SHA256_Stream.Hash (M);
      Public (D'Address, D'Length);
      Fold (D (0));
   end;

   declare
      Key  : SB.Byte_Array (0 .. 31) := [others => 16#0b#];
      Text : SB.Byte_Array (0 .. 49) := [others => 16#dd#];
      D    : SB.Digest;
   begin
      Secret (Key'Address, Key'Length);
      Secret (Text'Address, Text'Length);
      D := Foundation_Spark.HMAC.SHA256_Impl.HMAC_SHA256 (Key, Text);
      Public (D'Address, D'Length);
      Fold (D (0));
   end;

   Ada.Text_IO.Put_Line ("ct_grind done, sum" & Sum'Image);
end CT_Grind;
