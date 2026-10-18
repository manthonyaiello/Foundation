--  The exports Cryptol calls for algorithms/AES/KeyExpansion.cry: spark_<Name>
--  for each ghost shim in AES_KeyExpansion, the names that
--  spark/cryptol/SPARK/AES/KeyExpansion.cry declares foreign. Each calls its
--  shim through an Import of the shim's link name,
--  Ghost_Link_Prefix & its External_Name (see Foundation_Spark.FFI and
--  AES_GF28_Exports). Each Ghost_<Name> Import has Global => null, which
--  is what the shim's own (proved) Global is: it reads no state; and
--  Always_Terminates, since the shim is one call of a spec function,
--  whose recursion gnatprove proves terminates (Subprogram_Variant).

with Foundation_Spark.AES.Spec.Types;
with Foundation_Spark.FFI.AES_Types;

package Foundation_Spark.FFI.AES_KeyExpansion_Exports with
  SPARK_Mode
is

   use Foundation_Spark.AES.Spec.Types;
   use Foundation_Spark.FFI.AES_Types;

   procedure Ghost_RotWord (A : AESWord; Output : out AESWord)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_RotWord",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_KeyExpansion.RotWord, by its link name.
   --  @param A The word.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure RotWord (A : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_RotWord";
   --  Cryptol's foreign spark_RotWord :
   --  AESWord -> AESWord.
   --  Calls Ghost_RotWord.
   --  @param A The word.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_SubWord (A : AESWord; Output : out AESWord)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_SubWord",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_KeyExpansion.SubWord, by its link name.
   --  @param A The word.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure SubWord (A : AESWord; Output : out AESWord)
   with
     Export,
     Convention    => C,
     External_Name => "spark_SubWord";
   --  Cryptol's foreign spark_SubWord :
   --  AESWord -> AESWord.
   --  Calls Ghost_SubWord.
   --  @param A The word.
   --  @param Output The result, written through Cryptol's output pointer.

   procedure Ghost_KeyExpansion
     (K : C_Size; Key : All_Key_Words; Output : in out All_Round_Keys)
   with
     Import,
     Convention    => C,
     External_Name => Ghost_Link_Prefix & "spark_KeyExpansion",
     Global        => null,
     Always_Terminates;
   --  The ghost shim AES_KeyExpansion.KeyExpansion, by its link name.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key words (the first Nk (K)).
   --  @param Output The result, written through Cryptol's output pointer.

   procedure KeyExpansion
     (K : C_Size; Key : All_Key_Words; Output : in out All_Round_Keys)
   with
     Export,
     Convention    => C,
     External_Name => "spark_KeyExpansion";
   --  Cryptol's foreign spark_KeyExpansion :
   --  {k} (Key k) => [Nk k]AESWord -> [Nr k + 1]Block.
   --  Calls Ghost_KeyExpansion.
   --  @param K The key size, Cryptol's {k}.
   --  @param Key The key words (the first Nk (K)).
   --  @param Output The result, written through Cryptol's output pointer.

end Foundation_Spark.FFI.AES_KeyExpansion_Exports;
