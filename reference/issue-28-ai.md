# AI command ordering regression repair

The #28 human movement-before-fire correction also changed the AI branch. Original frame 2 lines 305–316 fire before moving. Restoring that distinction fixes rejected AI specials without changing human ordering, RNG probabilities, seeds, or balance.

`ai_order-v1` executes the source polling function in original Sprite 564 scope, adapting only its 11 `RandomNumber` opcodes to a fixture tape. FFDec preserves branch/container destinations while inserting the replacement calls. The tape `[99,0,3]` selects the fire branch and rightward movement; exactly three calls are required. Original function bodies, weapon creation and movement callbacks remain source bytecode. This is controlled-decision evidence, not an RNG-distribution test or Adobe Flash certification. Provenance records original and adapted polling hashes separately.

Seven cases cover ordinary bombs and all six specials over six ticks (504 fields). Source fires down while stationary, then faces/moves right. Before correction, six special cases diverged; afterward all rows match. The public actors runner includes this independent reference. All 28 human ordering cases still pass.

The public soak runner now rejects zero bomb or special activity. It failed before the correction with both counts zero. With unchanged 18 seeds and 21,600 ticks it passes, exercising 508 bombs and 151 specials with inventory and nonnegative-energy invariants. Those counts describe the concurrent #29 scheduler; the standalone repair also passes the actors, AI-reference, specials, human-reference and soak checks (retained standalone logs).

Evidence is in [issue-28-ai-evidence](issue-28-ai-evidence). This repair is committed separately from #29 scheduling so its origin and scope remain explicit.
