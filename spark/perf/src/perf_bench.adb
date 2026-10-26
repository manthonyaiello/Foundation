--  The SPARK side of the AES benchmark; perf/rust/src/main.rs is
--  the Rust side, and does the same thing in the same order.
--
--  First the FIPS-197 Appendix C known answers go through the build under
--  test (C.1, C.2, C.3: encrypt, then both decryptions back), printed as
--  "kat" lines that scripts/perf-aes.sh checks. Then, for k = 128, 192 and
--  256, each operation is timed in batches of Batch calls: Warm batches
--  are run and discarded, then Reps batches are timed, each with the
--  monotonic clock of Perf_Clock. Every call's output feeds the next call's
--  input, so no call can be hoisted or dropped. One "bench" line per
--  operation gives the time per call over the Reps batches, in nanoseconds:
--  median, minimum, first quartile, third quartile, maximum.
--
--  Usage: perf_bench [quick]   (quick: few, small batches, for a smoke test)

with Ada.Command_Line;
with Ada.Long_Float_Text_IO;
with Ada.Text_IO;
with Interfaces;
with Foundation_Spark.AES.Spec.Types;
with Perf_AES;
with Perf_Clock;

procedure Perf_Bench is

   use Foundation_Spark.AES.Spec.Types;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_64;

   Quick : constant Boolean :=
     Ada.Command_Line.Argument_Count > 0
     and then Ada.Command_Line.Argument (1) = "quick";
   --  A smoke test rather than a measurement.

   Warm  : constant Positive := (if Quick then 2 else 20);
   --  Batches run before timing, and discarded.

   Reps  : constant Positive := (if Quick then 5 else 101);
   --  Timed batches.

   Batch : constant Positive := (if Quick then 100 else 10_000);
   --  Calls per batch.

   type Samples is array (Positive range <>) of Long_Float;
   --  Times per call, one per batch, in nanoseconds.

   function Hex (B : Block) return String;
   --  A block in hexadecimal.
   --  @param B The block.
   --  @return 32 lowercase hexadecimal digits, byte 0 first.

   function Hex (B : Block) return String is
      Digits_Of : constant String := "0123456789abcdef";
      R         : String (1 .. 32);
   begin
      for I in Block_Index loop
         R (2 * I + 1) := Digits_Of (Natural (B (I) / 16) + 1);
         R (2 * I + 2) := Digits_Of (Natural (B (I) mod 16) + 1);
      end loop;
      return R;
   end Hex;

   function Img (X : Long_Float) return String;
   --  A time, with two decimals.
   --  @param X The time.
   --  @return Its image, without exponent or leading blanks.

   function Img (X : Long_Float) return String is
      S : String (1 .. 32);
   begin
      Ada.Long_Float_Text_IO.Put (S, X, Aft => 2, Exp => 0);
      for I in S'Range loop
         if S (I) /= ' ' then
            return S (I .. S'Last);
         end if;
      end loop;
      return S;
   end Img;

   procedure Report (Tag, Op : String; S : in out Samples);
   --  Sort S and print its "bench" line.
   --  @param Tag The key size, as "aes128".
   --  @param Op The operation.
   --  @param S The samples; sorted on return.

   procedure Report (Tag, Op : String; S : in out Samples) is
      N : constant Positive := S'Length;
      function At_Q (Q : Natural) return Long_Float is
        (S (S'First + (N - 1) * Q / 4));
      --  The Q-th quartile, by the nearest rank below.
      --  @param Q 0 to 4.
      --  @return The sample at that rank.
   begin
      for I in S'First + 1 .. S'Last loop
         declare
            X : constant Long_Float := S (I);
            J : Natural := I;
         begin
            while J > S'First and then S (J - 1) > X loop
               S (J) := S (J - 1);
               J := J - 1;
            end loop;
            S (J) := X;
         end;
      end loop;
      Ada.Text_IO.Put_Line
        ("bench " & Tag & " " & Op & " " & Img (At_Q (2)) & " "
         & Img (At_Q (0)) & " " & Img (At_Q (1)) & " " & Img (At_Q (3))
         & " " & Img (At_Q (4)));
   end Report;

   function Tag_Of (K : Key_Size) return String is
     (if K = 128 then "aes128" elsif K = 192 then "aes192" else "aes256");
   --  The key size's label.
   --  @param K The key size.
   --  @return "aes128", "aes192" or "aes256".

   procedure Known_Answer (K : Key_Size);
   --  FIPS-PUB-197 Appendix C at K: the key 00 01 02 ..., the plaintext
   --  00 11 22 ... ff. Prints the ciphertext and both decryptions of it.
   --  @param K The key size.

   procedure Known_Answer (K : Key_Size) is
      Key : constant Key_Words (0 .. Nk (K) - 1) :=
        [for I in 0 .. Nk (K) - 1 =>
           [for J in AESWord_Index => Byte (4 * I + J)]];
      W   : Round_Keys (0 .. Nr (K));
      PT  : constant Block := [for I in Block_Index => Byte (17 * I)];
      CT  : Block := PT;
      D   : Block;
   begin
      Perf_AES.Expand_Key (K, Key, W);
      Perf_AES.Encrypt (K, W, CT);
      Ada.Text_IO.Put_Line ("kat " & Tag_Of (K) & " encrypt " & Hex (CT));
      D := CT;
      Perf_AES.Decrypt (K, W, D);
      Ada.Text_IO.Put_Line ("kat " & Tag_Of (K) & " decrypt " & Hex (D));
      D := CT;
      Perf_AES.Decrypt_Prime (K, W, D);
      Ada.Text_IO.Put_Line
        ("kat " & Tag_Of (K) & " decrypt_prime " & Hex (D));
   end Known_Answer;

   type Size_List is array (1 .. 3) of Key_Size;
   --  The key sizes to run.

   Sizes : Size_List := [128, 192, 256]
   with Volatile;
   --  Volatile, so that the key size is not a constant the optimizer can
   --  specialize a wrapper for: the timed code is the library's general
   --  code, as perf/rust/src/main.rs passes its key sizes through
   --  black_box.

   Sink : Byte := 0;
   --  Folded from every result and printed, so nothing is dead code.

   procedure Bench (K : Key_Size);
   --  Time Expand_Key, Encrypt, Decrypt and Decrypt_Prime at K.
   --  @param K The key size.

   procedure Bench (K : Key_Size) is
      Key   : Key_Words (0 .. Nk (K) - 1) :=
        [for I in 0 .. Nk (K) - 1 =>
           [for J in AESWord_Index => Byte ((4 * I + J) mod 256)]];
      W     : Round_Keys (0 .. Nr (K));
      State : Block := [for I in Block_Index => Byte (I)];
      S     : Samples (1 .. Reps);
      T0    : Interfaces.Unsigned_64;
      Tag   : constant String := Tag_Of (K);

      type Op_Kind is (Encrypt, Decrypt, Decrypt_Prime);
      --  The block operations.

      procedure Blocks (Op : Op_Kind);
      --  Time one block operation and report it.
      --  @param Op The operation.

      procedure Blocks (Op : Op_Kind) is
      begin
         for R in 1 .. Warm + Reps loop
            T0 := Perf_Clock.Now;
            for N in 1 .. Batch loop
               case Op is
                  when Encrypt => Perf_AES.Encrypt (K, W, State);
                  when Decrypt => Perf_AES.Decrypt (K, W, State);
                  when Decrypt_Prime =>
                     Perf_AES.Decrypt_Prime (K, W, State);
               end case;
            end loop;
            if R > Warm then
               S (R - Warm) :=
                 Long_Float (Perf_Clock.Now - T0) / Long_Float (Batch);
            end if;
         end loop;
         Report
           (Tag,
            (case Op is
               when Encrypt => "encrypt",
               when Decrypt => "decrypt",
               when Decrypt_Prime => "decrypt_prime"),
            S);
      end Blocks;

   begin
      for R in 1 .. Warm + Reps loop
         T0 := Perf_Clock.Now;
         for N in 1 .. Batch loop
            Perf_AES.Expand_Key (K, Key, W);
            Key (0) (0) := Key (0) (0) xor W (Nr (K)) (0);
         end loop;
         if R > Warm then
            S (R - Warm) :=
              Long_Float (Perf_Clock.Now - T0) / Long_Float (Batch);
         end if;
      end loop;
      Report (Tag, "expand_key", S);
      Blocks (Encrypt);
      Blocks (Decrypt);
      Blocks (Decrypt_Prime);
      Sink := Sink xor State (0) xor Key (0) (0);
   end Bench;

begin
   for K of Sizes loop
      Known_Answer (K);
   end loop;
   for K of Sizes loop
      Bench (K);
   end loop;
   Ada.Text_IO.Put_Line ("sink" & Byte'Image (Sink));
end Perf_Bench;
