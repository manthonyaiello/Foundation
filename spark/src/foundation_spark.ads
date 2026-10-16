--  Root of the SPARK implementations of the Foundation Cryptol
--  specifications. Child packages mirror the algorithms/ tree:
--  common/ holds shared bit-sequence types, and each algorithm
--  directory holds a spec layer that tracks the Cryptol closely, plus
--  refinement layers that change representation.

package Foundation_Spark with
  SPARK_Mode,
  Pure
is
end Foundation_Spark;
