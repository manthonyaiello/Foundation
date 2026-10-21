--  A dudect-style timing test (issue #50), after Reparaz, Balasch and
--  Verbauwhede, "Dude, is my code constant time?" (DATE 2017): time one
--  operation on inputs of two classes, class 0 a fixed input and class 1 a
--  fresh random input per call, the classes interleaved at random, and
--  compare the two timing distributions with Welch's t-test, raw and cropped
--  at several percentiles. |t| above 4.5 is evidence of a timing difference
--  between the classes, and so of a leak of the secret input. A |t| below it
--  is no proof of constant time: it says only that this many samples on this
--  machine did not see one.
--
--  Usage: ct_dudect TARGET SAMPLES [evict]
--    TARGET is one of aes128_encrypt (secret: the plaintext),
--    aes128_decrypt (the ciphertext), aes128_key (the key: Expand_Key then
--    Encrypt_Block), sha256 (a 64-byte message), hmac_key (a 32-byte HMAC
--    key, 32-byte text). With "evict", every measurement is preceded by a
--    write over a buffer larger than the last-level cache, so that whatever
--    tables the operation reads start cold and a secret-dependent choice of
--    cache line can show in its time.
--
--  Inputs are made before timing, by a xorshift64* generator from a fixed
--  seed, so a run is repeatable in its inputs (not in its timings).

with Ada.Command_Line;
with Ada.Real_Time;
with Ada.Text_IO;
with Ada.Numerics.Long_Elementary_Functions;
with Interfaces;
with Foundation_Spark.AES.Impl;
with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.HMAC.SHA256_Impl;
with Foundation_Spark.SHA2.SHA256_Bytes;
with Foundation_Spark.SHA2.SHA256_Stream;

procedure CT_Dudect is

   use Ada.Real_Time;
   use Interfaces;
   use Foundation_Spark.AES.Spec.Types;

   package Impl renames Foundation_Spark.AES.Impl;
   package SB renames Foundation_Spark.SHA2.SHA256_Bytes;
   use type SB.Byte_Index;

   Batch : constant := 4;
   --  Calls per measurement, all of one class, to lift a measurement well
   --  above the clock's resolution and overhead.

   Input_Len : constant := 64;
   --  Bytes of input per call: the largest any target reads.

   subtype Input is SB.Byte_Array (0 .. Input_Len - 1);
   --  One call's input.

   type Input_Array is array (Positive range <>) of Input;
   --  The inputs of a run, Batch per measurement.

   type Class_Array is array (Positive range <>) of Natural range 0 .. 1;
   --  The class of each measurement.

   type Time_Array is array (Positive range <>) of Long_Float;
   --  The time of each measurement, in nanoseconds.

   State : Unsigned_64 := 16#9E37_79B9_7F4A_7C15#;
   --  The xorshift64* generator's state.

   function Next return Unsigned_64;
   --  The next xorshift64* output.
   --  @return 64 pseudo-random bits.

   function Next return Unsigned_64 is
   begin
      State := State xor Shift_Right (State, 12);
      State := State xor Shift_Left (State, 25);
      State := State xor Shift_Right (State, 27);
      return State * 16#2545_F491_4F6C_DD1D#;
   end Next;

   Evict_Len : constant := 64 * 1024 * 1024;
   --  Bytes written to evict the caches: more than any last-level cache of
   --  the machines this runs on.

   type Evict_Buffer is array (0 .. Evict_Len - 1) of Unsigned_8;
   --  The eviction buffer's type.

   type Evict_Access is access Evict_Buffer;
   --  The eviction buffer lives on the heap.

   Evict_Buf : Evict_Access;
   --  Allocated only with "evict".

   procedure Evict;
   --  Write one byte per 64-byte line of Evict_Buf.

   procedure Evict is
   begin
      for I in 0 .. Evict_Len / 64 - 1 loop
         Evict_Buf (64 * I) := Evict_Buf (64 * I) + 1;
      end loop;
   end Evict;

   --  The fixed secrets of the targets that keep one.

   Fixed_Key : constant Key_Words (0 .. 3) :=
     [[16#2b#, 16#7e#, 16#15#, 16#16#], [16#28#, 16#ae#, 16#d2#, 16#a6#],
      [16#ab#, 16#f7#, 16#15#, 16#88#], [16#09#, 16#cf#, 16#4f#, 16#3c#]];
   --  The key of FIPS-PUB-197 Appendix A.1.

   W128 : Round_Keys (0 .. 10);
   --  Fixed_Key's round keys.

   Sink : Unsigned_8 := 0;
   --  Folded from every result, so nothing is dead code.

   function To_Block (X : Input) return Block is
     ([for I in Block_Index => X (SB.Byte_Index (I))]);
   --  The first 16 bytes of an input, as a block.
   --  @param X The input.
   --  @return X (0 .. 15).

   procedure Op (Target : String; X : Input);
   --  One call of the target operation on X.
   --  @param Target The target's name.
   --  @param X The input.

   procedure Op (Target : String; X : Input) is
   begin
      if Target = "aes128_encrypt" then
         declare
            S : Block := To_Block (X);
         begin
            Impl.Encrypt_Block (128, W128, S);
            Sink := Sink xor S (0);
         end;
      elsif Target = "aes128_decrypt" then
         declare
            S : Block := To_Block (X);
         begin
            Impl.Decrypt_Block (128, W128, S);
            Sink := Sink xor S (0);
         end;
      elsif Target = "aes128_key" then
         declare
            Key : constant Key_Words (0 .. 3) :=
              [for I in 0 .. 3 =>
                 [for J in AESWord_Index => X (SB.Byte_Index (4 * I + J))]];
            W   : Round_Keys (0 .. 10);
            S   : Block := [others => 0];
         begin
            Impl.Expand_Key (128, Key, W);
            Impl.Encrypt_Block (128, W, S);
            Sink := Sink xor S (0);
         end;
      elsif Target = "sha256" then
         declare
            D : constant SB.Digest := Foundation_Spark.SHA2.SHA256_Stream.Hash (X);
         begin
            Sink := Sink xor D (0);
         end;
      elsif Target = "hmac_key" then
         declare
            D : constant SB.Digest :=
              Foundation_Spark.HMAC.SHA256_Impl.HMAC_SHA256
                (X (0 .. 31), X (32 .. 63));
         begin
            Sink := Sink xor D (0);
         end;
      else
         raise Constraint_Error with "unknown target " & Target;
      end if;
   end Op;

   function T_Stat
     (Times : Time_Array; Classes : Class_Array; Limit : Long_Float)
      return Long_Float;
   --  Welch's t statistic of class 0 against class 1, over the measurements
   --  no longer than Limit.
   --  @param Times The measurements.
   --  @param Classes Their classes.
   --  @param Limit The crop threshold.
   --  @return t, or 0.0 when a class has fewer than two measurements.

   function T_Stat
     (Times : Time_Array; Classes : Class_Array; Limit : Long_Float)
      return Long_Float
   is
      N    : array (0 .. 1) of Long_Float := [0.0, 0.0];
      Mean : array (0 .. 1) of Long_Float := [0.0, 0.0];
      M2   : array (0 .. 1) of Long_Float := [0.0, 0.0];
      D    : Long_Float;
   begin
      for I in Times'Range loop
         if Times (I) <= Limit then
            declare
               C : constant Natural := Classes (I);
            begin
               N (C) := N (C) + 1.0;
               D := Times (I) - Mean (C);
               Mean (C) := Mean (C) + D / N (C);
               M2 (C) := M2 (C) + D * (Times (I) - Mean (C));
            end;
         end if;
      end loop;
      if N (0) < 2.0 or else N (1) < 2.0 then
         return 0.0;
      end if;
      declare
         V0 : constant Long_Float := M2 (0) / (N (0) - 1.0);
         V1 : constant Long_Float := M2 (1) / (N (1) - 1.0);
         Se : constant Long_Float := V0 / N (0) + V1 / N (1);
      begin
         if Se <= 0.0 then
            return 0.0;
         end if;
         return (Mean (0) - Mean (1))
           / Ada.Numerics.Long_Elementary_Functions.Sqrt (Se);
      end;
   end T_Stat;

   function Percentile (Times : Time_Array; P : Long_Float) return Long_Float;
   --  The P-th percentile of the first measurements (up to 10 000).
   --  @param Times The measurements.
   --  @param P The percentile, 0.0 .. 100.0.
   --  @return The threshold.

   function Percentile (Times : Time_Array; P : Long_Float) return Long_Float
   is
      Last : constant Positive :=
        Times'First + Natural'Min (Times'Length, 10_000) - 1;
      S    : Time_Array := Times (Times'First .. Last);
      Tmp  : Long_Float;
      J    : Natural;
   begin
      --  Insertion sort: 10 000 values, once per percentile.
      for I in S'First + 1 .. S'Last loop
         Tmp := S (I);
         J := I - 1;
         while J >= S'First and then S (J) > Tmp loop
            S (J + 1) := S (J);
            J := J - 1;
         end loop;
         S (J + 1) := Tmp;
      end loop;
      return S (S'First
                + Natural (Long_Float (S'Length - 1) * P / 100.0));
   end Percentile;

   procedure Run (Target : String; Samples : Positive; Do_Evict : Boolean);
   --  Measure and report one target.
   --  @param Target The target's name.
   --  @param Samples The number of measurements.
   --  @param Do_Evict Whether to evict the caches before each measurement.

   procedure Run (Target : String; Samples : Positive; Do_Evict : Boolean) is
      Fixed   : constant Input := [for I in Input'Range => Unsigned_8 (I)];
      Inputs  : access Input_Array := new Input_Array (1 .. Samples * Batch);
      Classes : access Class_Array := new Class_Array (1 .. Samples);
      Times   : access Time_Array := new Time_Array (1 .. Samples);
      Start   : Time;
      Max_T   : Long_Float := 0.0;
      Pcts    : constant array (1 .. 6) of Long_Float :=
        [50.0, 75.0, 90.0, 95.0, 99.0, 99.9];
   begin
      for I in 1 .. Samples loop
         Classes (I) := Natural (Next and 1);
         for B in 1 .. Batch loop
            if Classes (I) = 0 then
               Inputs ((I - 1) * Batch + B) := Fixed;
            else
               Inputs ((I - 1) * Batch + B) :=
                 [for J in Input'Range => Unsigned_8 (Next and 16#FF#)];
            end if;
         end loop;
      end loop;

      --  Warm up: one pass over a thousand inputs, untimed.
      for I in 1 .. Natural'Min (Samples, 1000) loop
         Op (Target, Inputs (I));
      end loop;

      for I in 1 .. Samples loop
         if Do_Evict then
            Evict;
         end if;
         Start := Clock;
         for B in 1 .. Batch loop
            Op (Target, Inputs ((I - 1) * Batch + B));
         end loop;
         Times (I) := Long_Float (To_Duration (Clock - Start)) * 1.0E9;
      end loop;

      declare
         T : constant Long_Float := T_Stat (Times.all, Classes.all, Long_Float'Last);
      begin
         Ada.Text_IO.Put ("target " & Target & " samples" & Samples'Image
                          & " evict " & Do_Evict'Image
                          & " t_raw" & Long_Float'Image (T));
         Max_T := abs T;
      end;
      for P of Pcts loop
         declare
            T : constant Long_Float :=
              T_Stat (Times.all, Classes.all, Percentile (Times.all, P));
         begin
            Ada.Text_IO.Put (" t_p" & Long_Float'Image (P) & "="
                             & Long_Float'Image (T));
            Max_T := Long_Float'Max (Max_T, abs T);
         end;
      end loop;
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line
        ("target " & Target & " max_abs_t" & Long_Float'Image (Max_T)
         & (if Max_T > 4.5 then " LEAK (|t| > 4.5)"
            else " no evidence (|t| <= 4.5)")
         & " sink" & Sink'Image);
   end Run;

   use Ada.Command_Line;

begin
   if Argument_Count < 2 then
      Ada.Text_IO.Put_Line ("usage: ct_dudect TARGET SAMPLES [evict]");
      Set_Exit_Status (2);
      return;
   end if;
   Impl.Expand_Key (128, Fixed_Key, W128);
   declare
      Do_Evict : constant Boolean :=
        Argument_Count >= 3 and then Argument (3) = "evict";
   begin
      if Do_Evict then
         Evict_Buf := new Evict_Buffer'(others => 0);
      end if;
      Run (Argument (1), Positive'Value (Argument (2)), Do_Evict);
   end;
end CT_Dudect;
