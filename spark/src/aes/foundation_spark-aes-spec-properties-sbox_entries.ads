--  SBox.cry's SBoxCorrect, entry by entry: affine b == SBox @ b for each
--  of the 256 bytes b, by evaluation. Lemma_SBox_Entry states one entry;
--  sixteen row lemmas, one per value of b / 16, each prove sixteen
--  entries, so that each is analyzed on its own.
--
--  For each byte, the body lists the states that GF2.cry's pgcd's inner
--  passes through computing inverse b SBoxPolynomial, one Lemma_Step per
--  step of inner, from the last back to the first. The provers check each
--  step, evaluating pdiv and pmult on constants, and then the affine
--  transformation of the inverse that the final state gives.

package Foundation_Spark.AES.Spec.Properties.SBox_Entries with
  SPARK_Mode,
  Pure,
  Ghost
is

   procedure Lemma_SBox_Row_0 (B : Types.Byte)
   with
     Pre  => B / 16 = 0,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#00# .. 16#0F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_1 (B : Types.Byte)
   with
     Pre  => B / 16 = 1,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#10# .. 16#1F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_2 (B : Types.Byte)
   with
     Pre  => B / 16 = 2,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#20# .. 16#2F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_3 (B : Types.Byte)
   with
     Pre  => B / 16 = 3,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#30# .. 16#3F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_4 (B : Types.Byte)
   with
     Pre  => B / 16 = 4,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#40# .. 16#4F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_5 (B : Types.Byte)
   with
     Pre  => B / 16 = 5,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#50# .. 16#5F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_6 (B : Types.Byte)
   with
     Pre  => B / 16 = 6,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#60# .. 16#6F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_7 (B : Types.Byte)
   with
     Pre  => B / 16 = 7,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#70# .. 16#7F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_8 (B : Types.Byte)
   with
     Pre  => B / 16 = 8,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#80# .. 16#8F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_9 (B : Types.Byte)
   with
     Pre  => B / 16 = 9,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#90# .. 16#9F# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_A (B : Types.Byte)
   with
     Pre  => B / 16 = 10,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#A0# .. 16#AF# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_B (B : Types.Byte)
   with
     Pre  => B / 16 = 11,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#B0# .. 16#BF# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_C (B : Types.Byte)
   with
     Pre  => B / 16 = 12,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#C0# .. 16#CF# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_D (B : Types.Byte)
   with
     Pre  => B / 16 = 13,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#D0# .. 16#DF# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_E (B : Types.Byte)
   with
     Pre  => B / 16 = 14,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#E0# .. 16#EF# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Row_F (B : Types.Byte)
   with
     Pre  => B / 16 = 15,
     Post => SBox.Affine (B) = SBox.SBox (B);
   --  The entries 16#F0# .. 16#FF# of SBoxCorrect.
   --  @param B The byte.

   procedure Lemma_SBox_Entry (B : Types.Byte)
   with Post => SBox.Affine (B) = SBox.SBox (B);
   --  Entry B of SBoxCorrect: affine b == SBox @ b.
   --  @param B The byte.

end Foundation_Spark.AES.Spec.Properties.SBox_Entries;
