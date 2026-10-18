--  The AES spec layer. Each child mirrors one module of algorithms/AES at
--  minimal semantic distance: Types (Types.cry), GF28 (GF28.cry), SBox
--  (SBox.cry), KeyExpansion (KeyExpansion.cry), Cipher (Cipher.cry) and
--  Main (Main.cry).
--  The children other than Types are ghost: they state what the
--  implementation layer is proved equal to, and are compiled only when
--  ghost code is enabled (the FFI build).

package Foundation_Spark.AES.Spec with
  SPARK_Mode,
  Pure
is
end Foundation_Spark.AES.Spec;
