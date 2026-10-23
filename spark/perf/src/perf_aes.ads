--  The entry points the benchmark times and the size table measures (issue
--  #51): one non-inlined wrapper per AES operation, as perf/rust/src/lib.rs
--  has for the Rust. Whatever the optimizer inlines into a wrapper (at -O3
--  with LTO, usually the whole operation) is counted in its size, and every
--  timed call is one real call on both sides.

with Foundation_Spark.AES.Spec.Types;

package Perf_AES is

   use Foundation_Spark.AES.Spec.Types;

   procedure Expand_Key (K : Key_Size; Key : Key_Words; W : out Round_Keys)
   with No_Inline;
   --  AES.Impl.Expand_Key: KeyExpansion [FIPS-PUB-197 Section 5.2].
   --  @param K The key size in bits.
   --  @param Key The cipher key, Nk (K) words.
   --  @param W The round keys, Nr (K) + 1 blocks.

   procedure Encrypt (K : Key_Size; W : Round_Keys; State : in out Block)
   with No_Inline;
   --  AES.Impl.Encrypt_Block: Cipher [FIPS-PUB-197 Section 5.1].
   --  @param K The key size in bits.
   --  @param W The round keys.
   --  @param State The plaintext on entry, the ciphertext on exit.

   procedure Decrypt (K : Key_Size; W : Round_Keys; State : in out Block)
   with No_Inline;
   --  AES.Impl.Decrypt_Block: InvCipher [FIPS-PUB-197 Section 5.3].
   --  @param K The key size in bits.
   --  @param W The round keys.
   --  @param State The ciphertext on entry, the plaintext on exit.

   procedure Decrypt_Prime (K : Key_Size; W : Round_Keys; State : in out Block)
   with No_Inline;
   --  AES.Impl.Decrypt_Block_Prime: InvCipher', the rounds of Cipher undone
   --  in reverse order, the structure of NSA's Rust inv_cipher.
   --  @param K The key size in bits.
   --  @param W The round keys.
   --  @param State The ciphertext on entry, the plaintext on exit.

end Perf_AES;
