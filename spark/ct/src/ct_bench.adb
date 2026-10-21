--  Throughput of the AES implementation (issue #50): Expand_Key,
--  Encrypt_Block and Decrypt_Block at k = 128, 192 and 256, and SHA-256 over
--  one buffer. Each measurement chains its output into its next input, so
--  the optimizer cannot drop a call, and is repeated Reps times; the fastest
--  repetition is reported, to cut the noise of a shared machine. Times are
--  wall-clock (Ada.Real_Time), in nanoseconds per call or per byte.

with Ada.Command_Line;
with Ada.Real_Time;
with Ada.Text_IO;
with Interfaces;
with Foundation_Spark.AES.Impl;
with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.SHA2.SHA256_Bytes;
with Foundation_Spark.SHA2.SHA256_Stream;

procedure CT_Bench is

   use Ada.Real_Time;
   use Foundation_Spark.AES.Spec.Types;
   use type Interfaces.Unsigned_8;

   package Impl renames Foundation_Spark.AES.Impl;

   Reps : constant := 7;
   --  Repetitions of each measurement; the fastest is reported.

   Blocks : constant := 200_000;
   --  Blocks per encryption or decryption measurement.

   Keys : constant := 50_000;
   --  Key expansions per measurement.

   use type Foundation_Spark.SHA2.SHA256_Bytes.Byte_Index;

   function Min (A, B : Time_Span) return Time_Span is (if A < B then A else B);
   --  The shorter of two spans.
   --  @param A One span.
   --  @param B The other.
   --  @return The shorter.

   Sink : Interfaces.Unsigned_8 := 0;
   --  Folded from every result and printed, so nothing is dead code.

   function Ns (Span : Time_Span; N : Positive) return Long_Float is
     (Long_Float (To_Duration (Span)) * 1.0E9 / Long_Float (N));
   --  The time per call.
   --  @param Span The measured span.
   --  @param N The number of calls in it.
   --  @return Span / N, in nanoseconds.

   procedure Put (Label : String; Value : Long_Float; Unit : String);
   --  Print one result line.
   --  @param Label What was measured.
   --  @param Value The best time.
   --  @param Unit Its unit.

   procedure Put (Label : String; Value : Long_Float; Unit : String) is
      Img : constant String := Long_Float'Image (Value);
   begin
      Ada.Text_IO.Put_Line (Label & " " & Img & " " & Unit);
   end Put;

   procedure Bench_AES (K : Key_Size);
   --  Measure Expand_Key, Encrypt_Block and Decrypt_Block at K.
   --  @param K The key size.

   procedure Bench_AES (K : Key_Size) is
      Key   : Key_Words (0 .. Nk (K) - 1) :=
        [for I in 0 .. Nk (K) - 1 =>
           [for J in AESWord_Index => Byte ((4 * I + J) mod 256)]];
      W     : Round_Keys (0 .. Nr (K));
      State : Block := [for I in Block_Index => Byte (I)];
      Start : Time;
      Best  : Time_Span;
      Tag   : constant String := "aes" & Key_Size'Image (K);
   begin
      Best := Time_Span_Last;
      for R in 1 .. Reps loop
         Start := Clock;
         for N in 1 .. Keys loop
            Impl.Expand_Key (K, Key, W);
            Key (0) (0) := Key (0) (0) xor W (Nr (K)) (0);
         end loop;
         Best := Min (Best, Clock - Start);
      end loop;
      Put (Tag & " expand_key", Ns (Best, Keys), "ns/call");

      Best := Time_Span_Last;
      for R in 1 .. Reps loop
         Start := Clock;
         for N in 1 .. Blocks loop
            Impl.Encrypt_Block (K, W, State);
         end loop;
         Best := Min (Best, Clock - Start);
      end loop;
      Put (Tag & " encrypt_block", Ns (Best, Blocks), "ns/block");

      Best := Time_Span_Last;
      for R in 1 .. Reps loop
         Start := Clock;
         for N in 1 .. Blocks loop
            Impl.Decrypt_Block (K, W, State);
         end loop;
         Best := Min (Best, Clock - Start);
      end loop;
      Put (Tag & " decrypt_block", Ns (Best, Blocks), "ns/block");
      Sink := Sink xor State (0);
   end Bench_AES;

   procedure Bench_SHA256;
   --  Measure SHA-256 over a 64 KiB buffer.

   procedure Bench_SHA256 is
      Len   : constant := 65_536;
      Times : constant := 50;
      M     : Foundation_Spark.SHA2.SHA256_Bytes.Byte_Array (0 .. Len - 1) :=
        [for I in 0 .. Len - 1 => Interfaces.Unsigned_8 (I mod 251)];
      D     : Foundation_Spark.SHA2.SHA256_Stream.Digest;
      Start : Time;
      Best  : Time_Span := Time_Span_Last;
   begin
      for R in 1 .. Reps loop
         Start := Clock;
         for N in 1 .. Times loop
            D := Foundation_Spark.SHA2.SHA256_Stream.Hash (M);
            M (0) := M (0) xor D (0);
         end loop;
         Best := Min (Best, Clock - Start);
      end loop;
      Put ("sha256 hash_64KiB", Ns (Best, Times * Len), "ns/byte");
      Sink := Sink xor M (0);
   end Bench_SHA256;

begin
   Bench_AES (128);
   Bench_AES (192);
   Bench_AES (256);
   if Ada.Command_Line.Argument_Count = 0 then
      Bench_SHA256;
   end if;
   Ada.Text_IO.Put_Line ("sink" & Interfaces.Unsigned_8'Image (Sink));
end CT_Bench;
