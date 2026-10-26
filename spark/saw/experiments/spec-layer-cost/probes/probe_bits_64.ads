--  #69 probe: Probe_Bits at a 64-bit index.

with Probe_Bits;

package Probe_Bits_64 is
   type Index is range 0 .. 2 ** 62;
   package P is new Probe_Bits (Index);
end Probe_Bits_64;
