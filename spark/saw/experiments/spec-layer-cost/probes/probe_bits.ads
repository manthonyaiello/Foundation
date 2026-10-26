--  Spec-layer cost probe (not part of the crate; never proved by gnatprove, never
--  linked into the library): one function of the SHA-2 spec layer written
--  several ways, each one change away from the spec layer as it is, so
--  that SAW's cost can be measured one feature at a time. Compiled by
--  saw/experiments/spec-layer-cost/run.sh -p with the spec layer's switches
--  (-fno-inline, ghost on), and linked with the secondary stack.
--
--  Generic over the bit index, so that the 128-bit index of SHA2.Bits
--  (Probe_Bits_128) and a 64-bit one (Probe_Bits_64) can be compared.

with Interfaces;

generic
   type Index is range <>;
package Probe_Bits is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   type Bits is array (Index range <>) of Boolean;
   --  As SHA2.Bits: one Boolean (a byte) per bit.

   subtype Bits_64 is Bits (0 .. 63);
   --  A constrained 64-bit sequence: returned through a hidden pointer
   --  (sret), not on the secondary stack.

   type Byte_Array is array (Index range <>) of Interfaces.Unsigned_8;
   --  The same bits packed eight to a byte, most significant first.

   function Literal (Value, Width : Index) return Bits is
     (if Width = 0 then []
      else Literal (Value / 2, Width - 1) & [Value mod 2 = 1]);
   --  As the prelude's Bit_Sequences.Literal (SHA2.To_Bits), word for
   --  word: recursive, on the secondary stack.

   function Literal_No_Null (Value, Width : Index) return Bits is
     (if Width = 0 then []
      elsif Width = 1 then [Value mod 2 = 1]
      else Literal_No_Null (Value / 2, Width - 1) & [Value mod 2 = 1]);
   --  Literal with Width = 1 a case of its own, so that no concatenation
   --  has a null left operand (the null range whose length GNAT-LLVM
   --  computes with a poisoned add).

   function Literal_Agg (Value, Width : Index) return Bits is
     ([for I in 0 .. Width - 1 => (Value / 2 ** Natural (Width - 1 - I)) mod 2 = 1]);
   --  Literal with no recursion: bit I is bit Width - 1 - I of Value, an
   --  iterated aggregate. Still on the secondary stack.

   function Literal_64 (Value : Index) return Bits_64 is
     ([for I in Bits_64'Range => (Value / 2 ** Natural (63 - I)) mod 2 = 1]);
   --  Literal_Agg at Width = 64 with a constrained result: no recursion,
   --  no secondary stack.

   function Value (P : Bits; First : Index; Count : Natural)
     return Interfaces.Unsigned_32
   is
     (if Count = 0 then 0
      else 2 * Value (P, First, Count - 1)
           + (if P (First + Index (Count) - 1) then 1 else 0));
   --  As the prelude's Join_Split.Value (SHA2's Word_Of), word for word:
   --  the Count bits of P from First, most significant first.

   function Bit_Of (P : Byte_Array; I : Index) return Boolean is
     ((P (I / 8) / 2 ** Natural (7 - I mod 8)) mod 2 = 1);
   --  Bit I of the packed bits: bit 7 - I mod 8 of byte I / 8.

   function Value_Packed (P : Byte_Array; First : Index; Count : Natural)
     return Interfaces.Unsigned_32
   is
     (if Count = 0 then 0
      else 2 * Value_Packed (P, First, Count - 1)
           + (if Bit_Of (P, First + Index (Count) - 1) then 1 else 0));
   --  Value on the packed bits: the same recursion, an eighth of the
   --  elements.

end Probe_Bits;
