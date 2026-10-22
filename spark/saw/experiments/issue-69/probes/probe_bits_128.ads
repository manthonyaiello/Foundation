--  #69 probe: Probe_Bits at SHA2.Bit_Index's range, a 128-bit integer.

with Probe_Bits;

package Probe_Bits_128 is
   type Index is range 0 .. 2 ** 126;
   package P is new Probe_Bits (Index);
end Probe_Bits_128;
