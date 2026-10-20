--  The ghost shims for algorithms/AES/KeyExpansion.cry: the spec's
--  RotWord, SubWord, Rcon and KeyExpansion, exported with Cryptol's C
--  calling convention (Foundation_Spark.FFI.AES_Types). They are checked by
--  spark/cryptol/SPARK/AES/KeyExpansion.cry.
--
--  An AESWord result is written through Output, the pointer Cryptol passes
--  after the arguments. KeyExpansion takes Cryptol's {k} as K and serves
--  all three key sizes: it reads the first Nk (K) words of Key and writes
--  the first Nr (K) + 1 blocks of Output, the size of the buffer Cryptol
--  passes, and no more. Output is in out so that the blocks it does not
--  write keep their value, which SPARK's flow analysis requires of an out
--  parameter that is not wholly written.
--
--  Ghost, because the spec layer is; AES_KeyExpansion_Exports gives each
--  the name Cryptol looks up (see Foundation_Spark.FFI).

with Foundation_Spark.AES.Spec.Dispatch;
with Foundation_Spark.AES.Spec.KeyExpansion;
with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.FFI.AES_Types;

package Foundation_Spark.FFI.AES_KeyExpansion with
  SPARK_Mode,
  Ghost
is

   use Foundation_Spark.AES.Spec.Types;
   use Foundation_Spark.FFI.AES_Types;

   procedure RotWord (A : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_RotWord",
     Post          =>
       Output = Foundation_Spark.AES.Spec.KeyExpansion.RotWord (A);
   --  KeyExpansion.cry's RotWord, as the spec states it.
   --  @param A The word.
   --  @param Output The spec's RotWord (A).

   procedure SubWord (A : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_SubWord",
     Post          =>
       Output = Foundation_Spark.AES.Spec.KeyExpansion.SubWord (A);
   --  KeyExpansion.cry's SubWord, as the spec states it.
   --  @param A The word.
   --  @param Output The spec's SubWord (A).

   procedure Rcon (I : Byte; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_Rcon",
     Pre           => I in 1 .. 10,
     Post          =>
       Output = Foundation_Spark.AES.Spec.KeyExpansion.Rcon (Natural (I));
   --  KeyExpansion.cry's Rcon @ i, as the spec states it, for the indices
   --  KeyExpansion reads (1 .. 10; the Cryptol's element 0 is undefined).
   --  @param I The index.
   --  @param Output The spec's Rcon (I).

   procedure KeyExpansion
     (K : C_Size; Key : All_Key_Words; Output : in out All_Round_Keys)
   with
     Export,
     Convention    => C,
     External_Name => "spark_KeyExpansion",
     Pre           => Is_Key_Size (K),
     Post          =>
       Output (0 .. Nr (Key_Size_Of (K))) =
         Foundation_Spark.AES.Spec.Dispatch.KeyExpansion
           (Key_Size_Of (K), Key_Words_Of (K, Key))
       and then Output (Nr (Key_Size_Of (K)) + 1 .. Max_Nr) =
                Output'Old (Nr (Key_Size_Of (K)) + 1 .. Max_Nr);
   --  KeyExpansion.cry's KeyExpansion`{k}, as the spec states it, for
   --  k = K.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key words: the first Nk (K) are read.
   --  @param Output The spec's KeyExpansion (K, Key (0 .. Nk (K) - 1)), in
   --  its first Nr (K) + 1 blocks; the rest is not written.

end Foundation_Spark.FFI.AES_KeyExpansion;
