--  Part of the SAW harness of the spec layer (M4.4, #59), not of the crate:
--  scripts/check-saw.sh compiles it to bitcode and links it into the spec
--  modules (saw/obj/spec/), with GNAT Pro's runtime units
--  System.Secondary_Stack and System.Soft_Links, also compiled to bitcode
--  from the runtime's sources. README "SAW", "The secondary stack".
--
--  The spec layer's functions that return an unconstrained array (a
--  Round_Keys, a bit sequence) return it on the secondary stack, through
--  System.Secondary_Stack.SS_Allocate, which finds the stack through the
--  soft link System.Soft_Links.Get_Sec_Stack. GNAT calls a soft link with
--  a static-chain ("nest") argument that the default target,
--  Get_Sec_Stack_NT, does not take; native code ignores it, but SAW's
--  simulator refuses a call whose arguments do not match the callee's.
--  The contracts therefore set the soft link to Get_Sec_Stack below, which
--  takes that argument and returns what Get_Sec_Stack_NT returns: the
--  environment task's secondary stack, NT_TSD.Sec_Stack_Ptr.

with System;
with System.Secondary_Stack;
with System.Soft_Links;

package SAW_Soft_Links is

   function Get_Sec_Stack (Link : System.Address)
     return System.Secondary_Stack.SS_Stack_Ptr
   is (System.Soft_Links.Get_Sec_Stack_NT);
   --  System.Soft_Links.Get_Sec_Stack_NT, with the static chain a call
   --  through the soft link passes.
   --  @param Link The static chain, ignored.
   --  @return The environment task's secondary stack.

end SAW_Soft_Links;
