with Foundation_Spark.AES.Impl;

package body Perf_AES is

   package Impl renames Foundation_Spark.AES.Impl;

   procedure Expand_Key (K : Key_Size; Key : Key_Words; W : out Round_Keys) is
   begin
      Impl.Expand_Key (K, Key, W);
   end Expand_Key;

   procedure Encrypt (K : Key_Size; W : Round_Keys; State : in out Block) is
   begin
      Impl.Encrypt_Block (K, W, State);
   end Encrypt;

   procedure Decrypt (K : Key_Size; W : Round_Keys; State : in out Block) is
   begin
      Impl.Decrypt_Block (K, W, State);
   end Decrypt;

   procedure Decrypt_Prime (K : Key_Size; W : Round_Keys; State : in out Block)
   is
   begin
      Impl.Decrypt_Block_Prime (K, W, State);
   end Decrypt_Prime;

end Perf_AES;
