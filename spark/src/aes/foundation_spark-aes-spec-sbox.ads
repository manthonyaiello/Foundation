--  The S-boxes, mirroring algorithms/AES/SBox.cry [FIPS-PUB-197 Sections
--  5.1.1 and 5.3.2].
--
--  The tables are SBox.cry's, entry for entry. SBoxPolynomial and the
--  affine construction (affine) are SBox.cry's too: its property
--  SBoxCorrect, stated and proved in Foundation_Spark.AES.Spec.Properties
--  from the child SBox_Entries, checks the table against affine.

with Foundation_Spark.AES.Spec.GF2;
with Foundation_Spark.AES.Spec.GF28;
with Foundation_Spark.AES.Spec.Types;

package Foundation_Spark.AES.Spec.SBox with
  SPARK_Mode,
  Pure,
  Ghost
is

   SBox : constant Types.Byte_Table :=
     [16#63#, 16#7c#, 16#77#, 16#7b#, 16#f2#, 16#6b#, 16#6f#, 16#c5#,
      16#30#, 16#01#, 16#67#, 16#2b#, 16#fe#, 16#d7#, 16#ab#, 16#76#,
      16#ca#, 16#82#, 16#c9#, 16#7d#, 16#fa#, 16#59#, 16#47#, 16#f0#,
      16#ad#, 16#d4#, 16#a2#, 16#af#, 16#9c#, 16#a4#, 16#72#, 16#c0#,
      16#b7#, 16#fd#, 16#93#, 16#26#, 16#36#, 16#3f#, 16#f7#, 16#cc#,
      16#34#, 16#a5#, 16#e5#, 16#f1#, 16#71#, 16#d8#, 16#31#, 16#15#,
      16#04#, 16#c7#, 16#23#, 16#c3#, 16#18#, 16#96#, 16#05#, 16#9a#,
      16#07#, 16#12#, 16#80#, 16#e2#, 16#eb#, 16#27#, 16#b2#, 16#75#,
      16#09#, 16#83#, 16#2c#, 16#1a#, 16#1b#, 16#6e#, 16#5a#, 16#a0#,
      16#52#, 16#3b#, 16#d6#, 16#b3#, 16#29#, 16#e3#, 16#2f#, 16#84#,
      16#53#, 16#d1#, 16#00#, 16#ed#, 16#20#, 16#fc#, 16#b1#, 16#5b#,
      16#6a#, 16#cb#, 16#be#, 16#39#, 16#4a#, 16#4c#, 16#58#, 16#cf#,
      16#d0#, 16#ef#, 16#aa#, 16#fb#, 16#43#, 16#4d#, 16#33#, 16#85#,
      16#45#, 16#f9#, 16#02#, 16#7f#, 16#50#, 16#3c#, 16#9f#, 16#a8#,
      16#51#, 16#a3#, 16#40#, 16#8f#, 16#92#, 16#9d#, 16#38#, 16#f5#,
      16#bc#, 16#b6#, 16#da#, 16#21#, 16#10#, 16#ff#, 16#f3#, 16#d2#,
      16#cd#, 16#0c#, 16#13#, 16#ec#, 16#5f#, 16#97#, 16#44#, 16#17#,
      16#c4#, 16#a7#, 16#7e#, 16#3d#, 16#64#, 16#5d#, 16#19#, 16#73#,
      16#60#, 16#81#, 16#4f#, 16#dc#, 16#22#, 16#2a#, 16#90#, 16#88#,
      16#46#, 16#ee#, 16#b8#, 16#14#, 16#de#, 16#5e#, 16#0b#, 16#db#,
      16#e0#, 16#32#, 16#3a#, 16#0a#, 16#49#, 16#06#, 16#24#, 16#5c#,
      16#c2#, 16#d3#, 16#ac#, 16#62#, 16#91#, 16#95#, 16#e4#, 16#79#,
      16#e7#, 16#c8#, 16#37#, 16#6d#, 16#8d#, 16#d5#, 16#4e#, 16#a9#,
      16#6c#, 16#56#, 16#f4#, 16#ea#, 16#65#, 16#7a#, 16#ae#, 16#08#,
      16#ba#, 16#78#, 16#25#, 16#2e#, 16#1c#, 16#a6#, 16#b4#, 16#c6#,
      16#e8#, 16#dd#, 16#74#, 16#1f#, 16#4b#, 16#bd#, 16#8b#, 16#8a#,
      16#70#, 16#3e#, 16#b5#, 16#66#, 16#48#, 16#03#, 16#f6#, 16#0e#,
      16#61#, 16#35#, 16#57#, 16#b9#, 16#86#, 16#c1#, 16#1d#, 16#9e#,
      16#e1#, 16#f8#, 16#98#, 16#11#, 16#69#, 16#d9#, 16#8e#, 16#94#,
      16#9b#, 16#1e#, 16#87#, 16#e9#, 16#ce#, 16#55#, 16#28#, 16#df#,
      16#8c#, 16#a1#, 16#89#, 16#0d#, 16#bf#, 16#e6#, 16#42#, 16#68#,
      16#41#, 16#99#, 16#2d#, 16#0f#, 16#b0#, 16#54#, 16#bb#, 16#16#];
   --  SBox.cry: SBox : [256][8]. The S-box [FIPS-PUB-197 Section 5.1.1 and
   --  Table 4], read as SBox (B) for Cryptol's SBox @ b.

   InvSBox : constant Types.Byte_Table :=
     [16#52#, 16#09#, 16#6a#, 16#d5#, 16#30#, 16#36#, 16#a5#, 16#38#,
      16#bf#, 16#40#, 16#a3#, 16#9e#, 16#81#, 16#f3#, 16#d7#, 16#fb#,
      16#7c#, 16#e3#, 16#39#, 16#82#, 16#9b#, 16#2f#, 16#ff#, 16#87#,
      16#34#, 16#8e#, 16#43#, 16#44#, 16#c4#, 16#de#, 16#e9#, 16#cb#,
      16#54#, 16#7b#, 16#94#, 16#32#, 16#a6#, 16#c2#, 16#23#, 16#3d#,
      16#ee#, 16#4c#, 16#95#, 16#0b#, 16#42#, 16#fa#, 16#c3#, 16#4e#,
      16#08#, 16#2e#, 16#a1#, 16#66#, 16#28#, 16#d9#, 16#24#, 16#b2#,
      16#76#, 16#5b#, 16#a2#, 16#49#, 16#6d#, 16#8b#, 16#d1#, 16#25#,
      16#72#, 16#f8#, 16#f6#, 16#64#, 16#86#, 16#68#, 16#98#, 16#16#,
      16#d4#, 16#a4#, 16#5c#, 16#cc#, 16#5d#, 16#65#, 16#b6#, 16#92#,
      16#6c#, 16#70#, 16#48#, 16#50#, 16#fd#, 16#ed#, 16#b9#, 16#da#,
      16#5e#, 16#15#, 16#46#, 16#57#, 16#a7#, 16#8d#, 16#9d#, 16#84#,
      16#90#, 16#d8#, 16#ab#, 16#00#, 16#8c#, 16#bc#, 16#d3#, 16#0a#,
      16#f7#, 16#e4#, 16#58#, 16#05#, 16#b8#, 16#b3#, 16#45#, 16#06#,
      16#d0#, 16#2c#, 16#1e#, 16#8f#, 16#ca#, 16#3f#, 16#0f#, 16#02#,
      16#c1#, 16#af#, 16#bd#, 16#03#, 16#01#, 16#13#, 16#8a#, 16#6b#,
      16#3a#, 16#91#, 16#11#, 16#41#, 16#4f#, 16#67#, 16#dc#, 16#ea#,
      16#97#, 16#f2#, 16#cf#, 16#ce#, 16#f0#, 16#b4#, 16#e6#, 16#73#,
      16#96#, 16#ac#, 16#74#, 16#22#, 16#e7#, 16#ad#, 16#35#, 16#85#,
      16#e2#, 16#f9#, 16#37#, 16#e8#, 16#1c#, 16#75#, 16#df#, 16#6e#,
      16#47#, 16#f1#, 16#1a#, 16#71#, 16#1d#, 16#29#, 16#c5#, 16#89#,
      16#6f#, 16#b7#, 16#62#, 16#0e#, 16#aa#, 16#18#, 16#be#, 16#1b#,
      16#fc#, 16#56#, 16#3e#, 16#4b#, 16#c6#, 16#d2#, 16#79#, 16#20#,
      16#9a#, 16#db#, 16#c0#, 16#fe#, 16#78#, 16#cd#, 16#5a#, 16#f4#,
      16#1f#, 16#dd#, 16#a8#, 16#33#, 16#88#, 16#07#, 16#c7#, 16#31#,
      16#b1#, 16#12#, 16#10#, 16#59#, 16#27#, 16#80#, 16#ec#, 16#5f#,
      16#60#, 16#51#, 16#7f#, 16#a9#, 16#19#, 16#b5#, 16#4a#, 16#0d#,
      16#2d#, 16#e5#, 16#7a#, 16#9f#, 16#93#, 16#c9#, 16#9c#, 16#ef#,
      16#a0#, 16#e0#, 16#3b#, 16#4d#, 16#ae#, 16#2a#, 16#f5#, 16#b0#,
      16#c8#, 16#eb#, 16#bb#, 16#3c#, 16#83#, 16#53#, 16#99#, 16#61#,
      16#17#, 16#2b#, 16#04#, 16#7e#, 16#ba#, 16#77#, 16#d6#, 16#26#,
      16#e1#, 16#69#, 16#14#, 16#63#, 16#55#, 16#21#, 16#0c#, 16#7d#];
   --  SBox.cry: InvSBox : [256][8]. The inverse S-box [FIPS-PUB-197
   --  Section 5.3.2 and Table 6], read as InvSBox (B) for InvSBox @ b.

   use type Types.Byte;

   SBoxPolynomial : constant GF2.Poly := 2#1_0001_1011#;
   --  SBox.cry: SBoxPolynomial = <| x^^8 + x^^4 + x^^3 + x + 1 |> : [9],
   --  the S-box irreducible polynomial [FIPS-PUB-197 Section 4.2].

   function Reversed_Bit (B : Types.Byte; I : GF28.Bit_Index) return Boolean
   is (GF28.Bit (B, 7 - I));
   --  Cryptol's (reverse b) @ i on a [8].
   --  @param B The byte.
   --  @param I The Cryptol index into reverse b.
   --  @return Bit 7 - I of B, in Cryptol's order.

   function Affine_Bit (Inv : Types.Byte; I : GF28.Bit_Index) return Boolean
   is (Reversed_Bit (Inv, I)
       xor Reversed_Bit (Inv, (I + 4) mod 8)
       xor Reversed_Bit (Inv, (I + 5) mod 8)
       xor Reversed_Bit (Inv, (I + 6) mod 8)
       xor Reversed_Bit (Inv, (I + 7) mod 8)
       xor Reversed_Bit (16#63#, I));
   --  SBox.cry, in affine: b'@i = b_@i ^ b_@((i+4) % 8) ^ b_@((i+5) % 8) ^
   --  b_@((i+6) % 8) ^ b_@((i+7) % 8) ^ c@i, where b_ = reverse Inv and
   --  c = reverse 0b01100011.
   --  @param Inv The byte whose reverse is the Cryptol's b_.
   --  @param I The Cryptol index i.
   --  @return b'@i.

   function Affine (B : Types.Byte) return Types.Byte
   is ((if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 0) then 16#01#
        else 0)
       or (if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 1) then 16#02#
           else 0)
       or (if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 2) then 16#04#
           else 0)
       or (if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 3) then 16#08#
           else 0)
       or (if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 4) then 16#10#
           else 0)
       or (if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 5) then 16#20#
           else 0)
       or (if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 6) then 16#40#
           else 0)
       or (if Affine_Bit (GF2.Inverse (B, SBoxPolynomial), 7) then 16#80#
           else 0));
   --  SBox.cry: affine b = reverse b', where b_ = reverse (inverse b
   --  SBoxPolynomial) and b' is Affine_Bit: the affine transformation
   --  [FIPS-PUB-197 Section 5.1.1] of the inverse of B. Reversing b' puts
   --  b'@i at Cryptol index 7 - i, which is the bit of value 2 ** i.
   --  @param B The Cryptol's b.
   --  @return affine b.

end Foundation_Spark.AES.Spec.SBox;
