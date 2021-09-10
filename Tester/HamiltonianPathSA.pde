import java.util.HashSet; //<>//
import java.util.Iterator;
import java.lang.System;

class HamiltonianPathSA implements Policy {
  int STEPS_RANDOMIZE = 1000;
  int STEPS_ANNEAL = 500;

  FastHPath plan = null;
  //int[] cachedPossibilites = new int[0];
  HamiltonianPathSA() {
  }
  void reset(Game g) {
    setPlan(g, aHamiltonianPath(g.head));
    for (int i = 0; i < STEPS_RANDOMIZE; i++) setPlan(g, generateRandomCutJoin(g, plan));
  }
  FastHPath debug_plan_after_food_update = null;
  float[] debug_energy = new float[0];
  float[] debug_energy_record = new float[0];
  int[] debug_encoded_possibilities_along_plan = new int[0];
  FastHPath[] debug_plans = new FastHPath[0];
  FastHPath[] debug_plans_old = new FastHPath[0];
  boolean[] debug_accepted = new boolean[0];
  FastHPath debug_me_please = null;
  ArrayList<Integer> debug_interesting_perturbations = new ArrayList<Integer>();

  boolean DEBUG_DONT = false;
  void updateFood(Game g) {
    setPlan(g, plan);
    if (DEBUG_DONT) anneal(g);
    DEBUG_DONT = true;
    if (DO_DEBUG) PAUSED = true;
  }
  int getDir(Game g) {
    int move = plan.pop();
    plan.computeTimingGrid();
    return move;
  }

  void setPlan(Game g, FastHPath newPlan) {
    plan = newPlan;
    if (plan.timingGrid == null) println("setPlan - plan.timingGrid is null");
    //cachedPossibilites = getAllPossibleChanges(g);
    //println("There are ", cachedPossibilites.length, " elements in cachedPossibilites");
    debug_plan_after_food_update = plan.copy();
    debug_plan_after_food_update.computeTimingGrid();
  }

  float energy(Game g, FastHPath p) {
    return energy_timetofood(g, p);
    //return energy_numConsecutiveASTARMoves(g, p);
    //return energy_timetofood(g, p) + 20 * energy_numConsecutiveASTARMoves(g, p);
  }
  float energy_timetofood(Game g, FastHPath p) {
    return p.timingGrid[g.food.x][g.food.y]-abs(g.food.x-p.start.x)-abs(g.food.y-p.start.y);
  }
  float energy_numConsecutiveASTARMoves(Game g, FastHPath p) {
    Pos pos = p.start.copy();
    for (int i = 0; i < p.size; i++) {
      int move = (int)p.tabs[(i+p.startPos)%p.size];
      if (move == UP && g.food.y >= pos.y) return abs(g.food.x-p.start.x)+abs(g.food.y-p.start.y)-i;
      if (move == LEFT && g.food.x >= pos.x) return abs(g.food.x-p.start.x)+abs(g.food.y-p.start.y)-i;
      if (move == DOWN && g.food.y <= pos.y) return abs(g.food.x-p.start.x)+abs(g.food.y-p.start.y)-i;
      if (move == RIGHT && g.food.x <= pos.x) return abs(g.food.x-p.start.x)+abs(g.food.y-p.start.y)-i;
      movePosByDir(pos, move);
    }
    return 0;
  }


  void anneal(Game g) {
    debug_energy = new float[STEPS_ANNEAL];
    debug_energy_record = new float[STEPS_ANNEAL];
    debug_plans = new FastHPath[STEPS_ANNEAL];
    debug_plans_old = new FastHPath[STEPS_ANNEAL];
    debug_accepted = new boolean[STEPS_ANNEAL];
    int disrespect_count = 0;
    int restarts_count = 0;
    FastHPath recordPlan = plan.copy();
    float recordEnergy = plan.timingGrid[g.food.x][g.food.y];
    for (int i = 0; i < STEPS_ANNEAL; i++) {
      debug_energy[i] = 0;
      debug_energy_record[i] = 0;
    }
    for (int i = 0; i < STEPS_ANNEAL; i++) {
      float temperature = float(STEPS_ANNEAL - i) / (STEPS_ANNEAL + 9.0*i);
      FastHPath newPlan = generateCandidate(g, float(i)/STEPS_ANNEAL);
      //newPlan = getRandomPerturbedPlan();
      if (newPlan == null) {
        println("NEWPLAN IS NULL");
      }
      if (newPlan == null || newPlan.isDirespectful(g.grid, g.snake_length, g.food)) {
        println("REJECTING CANDIDATE");

        newPlan = plan.copy();
        newPlan.computeTimingGrid();
      }
      float currentEnergy = energy(g, plan);
      float newEnergy = energy(g, newPlan);
      println("newEnergy : ", newEnergy);
      debug_energy[i] = newEnergy;
      debug_energy_record[i] = recordEnergy;
      boolean accepted = newEnergy < currentEnergy || random(1) < exp((currentEnergy - newEnergy) / temperature);
      debug_plans_old[i] = plan;
      if (accepted) {
        debug_energy_record[i] = newPlan.timingGrid[g.food.x][g.food.y];
        setPlan(g, newPlan);
        if (newEnergy <= recordEnergy) {
          recordEnergy = newEnergy;
          recordPlan = newPlan.copy();
          recordPlan.computeTimingGrid();
        }
      }
      float planEnergy = energy(g, plan);

      float restartProb = (planEnergy-recordEnergy)/2000.0;
      if (restartProb <= 0) restartProb = 0;
      else restartProb /= restartProb+1;
      if (random(1) < restartProb && false) {
        recordPlan.computeTimingGrid();
        setPlan(g, recordPlan);
        restarts_count++;
      }
      debug_plans[i] = newPlan;
      debug_accepted[i] = accepted;
    }
    println(round(float(100)*disrespect_count/STEPS_ANNEAL)+"% disrespectful, "+restarts_count+" restarts");
    plan = plan.copy();
    plan.computeTimingGrid();
    if (plan.timingGrid == null) println("plan = plan.copy(); - plan.timingGrid is null");
  }
  FastHPath generateCandidate(Game g, float time) {
    //float temperature_do_short = map(i, 0, STEPS_ANNEAL/1.1, 0.5, 0);
    //float temperature_do_short_NOTskipIfNotShortcut = map(i, 0, STEPS_ANNEAL/1.1, 0.5, 0);
    //float temperature_do_short_allowTailCutting = map(i, 0, STEPS_ANNEAL/1.1, 0.5, 0);
    //FastHPath newPlan;
    //boolean Do_Short_Opti = random(1) < temperature_do_short;
    //if (Do_Short_Opti) {
    //  boolean skipIfNotShortcut = ! (random(1) < temperature_do_short_NOTskipIfNotShortcut);
    //  boolean forbidTailCutting = random(1) < temperature_do_short_allowTailCutting;
    //  newPlan = getPerturbedPlanAlongPlannedPath(g, skipIfNotShortcut, forbidTailCutting);
    //  if (newPlan == null) newPlan = getRandomPerturbedPlan();//getRandomInterestingPerturbedPlan(g);
    //} else {
    //  newPlan = getRandomPerturbedPlan();//getRandomInterestingPerturbedPlan(g);
    //}
    //return newPlan;
    if (random(1) < time) {
      FastHPath shortcutPlan = generateShortcutPlan(g, 0.3);
      if (shortcutPlan != null) return shortcutPlan;
    }

    return generateRandomCutJoin(g, plan);
  }

  boolean exploreShortcutPlan(Game g, FastHPath pln, CutJoinConsumer consumer) {
    return exploreShortcutPlan(g, pln, consumer, 1.0);
  }
  boolean exploreShortcutPlan(Game g, FastHPath pln, CutJoinConsumer consumer, float strictness) {
    PriorityQueue<Pos> q_cuts = new PriorityQueue<Pos>(new Comparator<Pos>() {
      int compare(Pos cutPos1, Pos cutPos2) {
        int[] cutQuadrantValues1 = getSortedPlanValues(pln.timingGrid, cutPos1);
        int[] cutQuadrantValues2 = getSortedPlanValues(pln.timingGrid, cutPos2);
        return random(1) < strictness ? (cutQuadrantValues2[2]-cutQuadrantValues2[1]) - (cutQuadrantValues1[2]-cutQuadrantValues1[1]) : -1+2*floor(random(2));
      }
    }
    );
    int food_time = pln.timingGrid[g.food.x][g.food.y];
    exploreCutsAlongPlanToGoal(pln, g.food, new CutConsumer() {
      void consume(Pos cutPos) {
        int[] cutQuadrantValues = getSortedPlanValues(pln.timingGrid, cutPos);
        if (cutQuadrantValues[0]+1 != cutQuadrantValues[1] || cutQuadrantValues[2]+1 != cutQuadrantValues[3]) return;
        if (cutQuadrantValues[3] > food_time) return;
        q_cuts.add(cutPos.copy());
      }
    }
    );
    while (!q_cuts.isEmpty()) {
      Pos cutPos = q_cuts.poll();
      CutJoinConsumer wrapper_consumer = new CutJoinConsumer() {
        boolean consume(FastHPath pln, Pos cutPos, int[] cutQuadrantValues, int[] cutQuadrantPositions, Pos joinPos, int[] joinQuadrantValues, int[] joinQuadrantPositions) {
          if (food_time >= joinQuadrantValues[3]) return false;
          return consumer.consume(pln, cutPos, cutQuadrantValues, cutQuadrantPositions, joinPos, joinQuadrantValues, joinQuadrantPositions);
        }
      };
      exploreCut(g, pln, cutPos, wrapper_consumer, false, false, true);
      break;
    }
    return false;
  }
  FastHPath generateShortcutPlan(Game g, float strictness) {
    OutputPlanProducer producer = new OutputPlanProducer();
    exploreShortcutPlan(g, plan, producer, strictness);
    return producer.output_plan;
  }

  boolean exploreRandomCutJoin(Game g, FastHPath pln, CutJoinConsumer consumer) {
    for (int i = 0; i < 1000; i++) {
      Pos cutPos = new Pos(floor(random(GRID_SIZE-1)), floor(random(GRID_SIZE-1)));
      if (exploreCut(g, pln, cutPos, consumer, false, false, false)) return true;
    }
    println("Damn! exploreRandomCutJoin timed out");
    return false;
  }
  FastHPath generateRandomCutJoin(Game g, FastHPath pln) {
    OutputPlanProducer producer = new OutputPlanProducer();
    exploreRandomCutJoin(g, plan, producer);
    return producer.output_plan;
  }



  //ArrayList<Pos> debug_getPerturbedPlanAlongPlannedPath;
  //FastHPath getPerturbedPlanAlongPlannedPath(Game g, boolean skipIfNotShortcut, boolean forbidCuttingTail) {
  //  return getPerturbedPlanAlongPlannedPath(g, skipIfNotShortcut, forbidCuttingTail, false);
  //}
  //FastHPath getPerturbedPlanAlongPlannedPath(Game g, boolean skipIfNotShortcut, boolean forbidCuttingTail, boolean doDebug) {
  //  if (doDebug) debug_getPerturbedPlanAlongPlannedPath = new ArrayList<Pos>();
  //  HashSet<Integer> encodedPossibilities = new HashSet<Integer>();
  //  exploreCutsAlongPlanToGoal(plan, g.food, new CutConsumer() {
  //    void consume(Pos cutPos) {
  //      exploreEncodedPossibilitiesAtCutPosAndAddToHashSet(g, cutPos.copy(), encodedPossibilities, skipIfNotShortcut, forbidCuttingTail);
  //    }
  //  }
  //  );
  //  int[] encodedPossibilitiesOutput = new int[encodedPossibilities.size()];
  //  int i = 0;
  //  Iterator<Integer> it = encodedPossibilities.iterator();
  //  while (it.hasNext()) encodedPossibilitiesOutput[i++] = it.next();
  //  debug_encoded_possibilities_along_plan = encodedPossibilitiesOutput;
  //  if (encodedPossibilitiesOutput.length == 0) return null;
  //  int r_id = floor(random(encodedPossibilitiesOutput.length));
  //  return introducePerturbation(plan, encodedPossibilitiesOutput[r_id]);
  //}

  void exploreCutsAlongPlanToGoal(FastHPath pln, Pos goal, CutConsumer consumer) {
    Pos pos = pln.start.copy();
    Pos cutPos = new Pos(0, 0);
    for (int i = 0; i < pln.size; i++) {
      int move = (int)pln.tabs[(i+pln.startPos)%pln.size];
      for (int flip = 0; flip < 2; flip++) {
        cutPos.x = pos.x - int(((flip==1)&&(move==UP||move==DOWN))||(move==LEFT));
        cutPos.y = pos.y - int(((flip==1)&&(move==LEFT||move==RIGHT))||(move==UP));
        if (boxInBounds(cutPos))consumer.consume(cutPos);
      }
      movePosByDir(pos, move);
      if (pos.equals(goal)) break;
    }
  }

  boolean exploreCut(Game g, FastHPath pln, Pos cutPos, CutJoinConsumer consumer, boolean skipIfNotShortcut, boolean forbidCuttingTail, boolean refuseReversals) {
    if (!boxInBounds(cutPos)) return false;
    if (pln.timingGrid == null) println("exploreCut - plan.timingGrid is null");
    int[] cutQuadrantValues = getSortedPlanValues(pln.timingGrid, cutPos);
    if (cutQuadrantValues[0]+1 != cutQuadrantValues[1] || cutQuadrantValues[2]+1 != cutQuadrantValues[3]) return false;
    int[] cutQuadrantPositions = getSortedPlanPositions(pln.timingGrid, cutQuadrantValues, cutPos);
    //println("!!!!!!!!!!!!JKLMJKLJKLMJMKLJ");
    if (skipIfNotShortcut && cutQuadrantValues[3] > pln.timingGrid[g.food.x][g.food.y]) println(cutQuadrantValues[3], pln.timingGrid[g.food.x][g.food.y]);
    if (skipIfNotShortcut && cutQuadrantValues[3] > pln.timingGrid[g.food.x][g.food.y]) return false;
    //println("JKLMJKLJKLMJMKLJ");
    Pos pos = getQuadrantPos(cutPos, cutQuadrantPositions[1]);
    Pos joinPos = new Pos(0, 0);
    int loopMove_n = cutQuadrantValues[2] - cutQuadrantValues[1];
    for (int i = 0; i < loopMove_n; i++) {
      int move = (int)pln.tabs[(i+pln.startPos+cutQuadrantValues[1])%pln.size];
      for (int flip = 0; flip < 2; flip++) {
        joinPos.x = pos.x - int(((flip==1)&&(move==UP||move==DOWN))||(move==LEFT));
        joinPos.y = pos.y - int(((flip==1)&&(move==LEFT||move==RIGHT))||(move==UP));
        //consumer.consume(cutPos, joinPos);
        if (!boxInBounds(joinPos)) continue;
        if (joinPos.equals(cutPos)) continue;
        int[] joinQuadrantValues = getSortedPlanValues(pln.timingGrid, joinPos);
        if (joinQuadrantValues[0]+1 != joinQuadrantValues[1] || joinQuadrantValues[2]+1 != joinQuadrantValues[3]) continue; // needs to be cutable
        if (cutQuadrantValues[1] <= joinQuadrantValues[0] && joinQuadrantValues[3] <= cutQuadrantValues[2]) continue; // This would lead to two loops
        // basically the main hamiltonian path would no longer go through every tile in the grid
        int[] joinQuadrantPositions = getSortedPlanPositions(pln.timingGrid, joinQuadrantValues, joinPos);
        if (forbidCuttingTail && gridAtPos(g.grid, getQuadrantPos(joinPos, joinQuadrantPositions[2])) != 0) continue; // review this...
        Pos a, b;
        boolean REVERSED = cutQuadrantValues[0] > joinQuadrantValues[0];
        if (REVERSED && refuseReversals) continue;
        if (!REVERSED) {
          if (joinQuadrantValues[2] < cutQuadrantValues[3]) continue;
          if (consumer.consume(pln, cutPos, cutQuadrantValues, cutQuadrantPositions, joinPos, joinQuadrantValues, joinQuadrantPositions)) return true;
        } else {
          if (joinQuadrantValues[2] > cutQuadrantValues[3]) continue;
          if (consumer.consume(pln, joinPos, joinQuadrantValues, joinQuadrantPositions, cutPos, cutQuadrantValues, cutQuadrantPositions)) return true;
        }
      }
      movePosByDir(pos, move);
    }
    return false;
  }



  //FastHPath getRandomInterestingPerturbedPlan(Game g) {
  //  debug_interesting_perturbations = new ArrayList<Integer>();
  //  if (cachedPossibilites.length == 0) return null;
  //  for (int i = 0; i < 100; i++) {
  //    int perturbation = cachedPossibilites[floor(random(cachedPossibilites.length))];
  //    if (perturbationIsInteresting(g, perturbation)) return introducePerturbation(plan, perturbation);
  //  }
  //  ArrayList<Integer> interestingPerturbations = new ArrayList<Integer>();
  //  for (int i = 0; i < cachedPossibilites.length; i++) if (perturbationIsInteresting(g, cachedPossibilites[i])) interestingPerturbations.add(cachedPossibilites[i]);
  //  if (DO_DEBUG) println("interestingPerturbations.size() /  cachedPossibilites.length: ", interestingPerturbations.size(), " / ", cachedPossibilites.length);
  //  if (interestingPerturbations.size() == 0) return getRandomPerturbedPlan();
  //  debug_interesting_perturbations = interestingPerturbations;
  //  return introducePerturbation(plan, interestingPerturbations.get(floor(random(interestingPerturbations.size()))));
  //}

  //boolean perturbationIsInteresting(Game g, int encodedPerturbation) {
  //  Pos joinPos = new Pos(encodedPerturbation % GRID_SIZE, (encodedPerturbation/GRID_SIZE) % GRID_SIZE);
  //  encodedPerturbation /= GRID_SIZE*GRID_SIZE;
  //  Pos cutPos = new Pos(encodedPerturbation % GRID_SIZE, (encodedPerturbation/GRID_SIZE) % GRID_SIZE);
  //  int foodTiming = plan.timingGrid[g.food.x][g.food.y];
  //  if (plan.timingGrid[joinPos.x][joinPos.y] <= foodTiming) return true;
  //  if (plan.timingGrid[joinPos.x+1][joinPos.y] <= foodTiming) return true;
  //  if (plan.timingGrid[joinPos.x][joinPos.y+1] <= foodTiming) return true;
  //  if (plan.timingGrid[joinPos.x+1][joinPos.y+1] <= foodTiming) return true;
  //  if (plan.timingGrid[cutPos.x][joinPos.y] <= foodTiming) return true;
  //  if (plan.timingGrid[cutPos.x+1][joinPos.y] <= foodTiming) return true;
  //  if (plan.timingGrid[cutPos.x][joinPos.y+1] <= foodTiming) return true;
  //  if (plan.timingGrid[cutPos.x+1][joinPos.y+1] <= foodTiming) return true;
  //  return false;
  //}

  //FastHPath getRandomPerturbedPlan() {
  //  if (cachedPossibilites.length == 0) return null;
  //  return introducePerturbation(plan, cachedPossibilites[floor(random(cachedPossibilites.length))]);
  //}

  //int[] getAllPossibleChanges(Game g) {
  //  HashSet<Integer> encodedPossibilities = new HashSet<Integer>();
  //  //int[][] planTimingGrid = plan.timingGrid();
  //  for (int i = 0; i < GRID_SIZE-1; i++) {
  //    for (int j = 0; j < GRID_SIZE-1; j++) {
  //      Pos cutPos = new Pos(i, j);
  //      exploreEncodedPossibilitiesAtCutPosAndAddToHashSet(g, cutPos, encodedPossibilities);
  //    }
  //  }
  //  int[] encodedPossibilitiesOutput = new int[encodedPossibilities.size()];
  //  int i = 0;
  //  Iterator<Integer> it = encodedPossibilities.iterator();
  //  while (it.hasNext()) encodedPossibilitiesOutput[i++] = it.next();
  //  return encodedPossibilitiesOutput;
  //}

  //void exploreEncodedPossibilitiesAtCutPosAndAddToHashSet(Game g, Pos cutPos, HashSet<Integer> encodedPossibilities) {
  //  exploreEncodedPossibilitiesAtCutPosAndAddToHashSet(g, cutPos, encodedPossibilities, false, false);
  //}

  //void exploreEncodedPossibilitiesAtCutPosAndAddToHashSet(Game g, Pos cutPos, HashSet<Integer> encodedPossibilities, boolean skipIfNotShortcut, boolean forbidCuttingTail) {
  //  if (!boxInBounds(cutPos)) return;
  //  if (plan.timingGrid == null) println("exploreEncodedPossibilitiesAtCutPosAndAddToHashSet - plan.timingGrid is null");
  //  int[] cutQuadrantValues = getSortedPlanValues(plan.timingGrid, cutPos);
  //  if (cutQuadrantValues[0]+1 != cutQuadrantValues[1] || cutQuadrantValues[2]+1 != cutQuadrantValues[3]) return;
  //  //if (cutQuadrantValues[0] < 1) return; // Not sure if this should be here or not - I remember doing some testing some time ago and it seemed to make things crash less
  //  int[] cutQuadrantPositions = getSortedPlanPositions(plan.timingGrid, cutQuadrantValues, cutPos);
  //  //if (gridAtThing(g.grid, cutPos, cutQuadrantPositions[0]) != 0 || gridAtThing(g.grid, cutPos, cutQuadrantPositions[1]) != 0) continue;
  //  //if (gridAtThing(g.grid, cutPos, cutQuadrantPositions[2]) != 0 || gridAtThing(g.grid, cutPos, cutQuadrantPositions[3]) != 0) continue;
  //  //if (gridAtThing(g.grid, cutPos, cutQuadrantPositions[0]) != 0 && gridAtThing(g.grid, cutPos, cutQuadrantPositions[1]) != 0) continue; // More precise thinking should be done here
  //  //if (gridAtThing(g.grid, cutPos, cutQuadrantPositions[2]) != 0 && gridAtThing(g.grid, cutPos, cutQuadrantPositions[3]) != 0) continue;

  //  // Do I want these?
  //  if (abs(gridAtPos(g.grid, getQuadrantPos(cutPos, cutQuadrantPositions[0]))-gridAtPos(g.grid, getQuadrantPos(cutPos, cutQuadrantPositions[1])))==1) return;
  //  if (abs(gridAtPos(g.grid, getQuadrantPos(cutPos, cutQuadrantPositions[2]))-gridAtPos(g.grid, getQuadrantPos(cutPos, cutQuadrantPositions[3])))==1) return;

  //  if (skipIfNotShortcut && cutQuadrantValues[3] > plan.timingGrid[g.food.x][g.food.y]) return;

  //  //int dirQ0toQ3 = dirAtoB(cutQuadrantPositions[0], cutQuadrantPositions[3]);
  //  //int dirQ0toQ1 = dirAtoB(cutQuadrantPositions[0], cutQuadrantPositions[1]);

  //  Pos posAlongCutLoop = getQuadrantPos(cutPos, cutQuadrantPositions[1]);
  //  int loopMove_n = cutQuadrantValues[2] - cutQuadrantValues[1];
  //  for (int loopMove_i = 0; loopMove_i < loopMove_n; loopMove_i++) {
  //    int loopMove = (int)plan.tabs[(loopMove_i+plan.startPos+cutQuadrantValues[1])%plan.size];
  //    Pos nposAlongCutLoop = movePosByDirCopy(posAlongCutLoop, loopMove);
  //    for (int flip = 0; flip < 2; flip++) {
  //      Pos joinPos = new Pos(min(posAlongCutLoop.x, nposAlongCutLoop.x), min(posAlongCutLoop.y, nposAlongCutLoop.y));
  //      if (flip == 1) {
  //        if (posAlongCutLoop.x == nposAlongCutLoop.x) joinPos.x--;
  //        if (posAlongCutLoop.y == nposAlongCutLoop.y) joinPos.y--;
  //      }
  //      if (!boxInBounds(joinPos)) continue;
  //      if (joinPos.equals(cutPos)) continue;
  //      int[] joinQuadrantValues = getSortedPlanValues(plan.timingGrid, joinPos);

  //      if (joinQuadrantValues[0]+1 != joinQuadrantValues[1] || joinQuadrantValues[2]+1 != joinQuadrantValues[3]) continue; // needs to be cutable
  //      if (cutQuadrantValues[1] <= joinQuadrantValues[0] && joinQuadrantValues[3] <= cutQuadrantValues[2]) continue;
  //      //if (gridAtThing(g.grid, joinPos, cutQuadrantPositions[0]) != 0 || gridAtThing(g.grid, joinPos, cutQuadrantPositions[1]) != 0) continue;
  //      //if (gridAtThing(g.grid, joinPos, cutQuadrantPositions[2]) != 0 || gridAtThing(g.grid, joinPos, cutQuadrantPositions[3]) != 0) continue;
  //      // and some grid stuff too - like what's above really

  //      int[] joinQuadrantPositions = getSortedPlanPositions(plan.timingGrid, joinQuadrantValues, joinPos);
  //      if (forbidCuttingTail && gridAtPos(g.grid, getQuadrantPos(joinPos, joinQuadrantPositions[2])) != 0) continue;
  //      //if (abs(gridAtPos(g.grid, getQuadrantPos(joinPos, joinQuadrantPositions[0]))-gridAtPos(g.grid, getQuadrantPos(joinPos, joinQuadrantPositions[1])))==1) continue;
  //      //if (abs(gridAtPos(g.grid, getQuadrantPos(joinPos, joinQuadrantPositions[2]))-gridAtPos(g.grid, getQuadrantPos(joinPos, joinQuadrantPositions[3])))==1) continue;

  //      Pos a, b;
  //      boolean REVERSED = cutQuadrantValues[0] > joinQuadrantValues[0];
  //      if (!REVERSED) {
  //        a = cutPos;
  //        b = joinPos;
  //        if (joinQuadrantValues[2] - cutQuadrantValues[3] < 0) continue;
  //      } else {
  //        a = joinPos;
  //        b = cutPos;
  //        if (joinQuadrantValues[2] - cutQuadrantValues[3] > 0) continue;
  //      }
  //      int encoded = ((a.y*GRID_SIZE + a.x)*GRID_SIZE + b.y)*GRID_SIZE + b.x;
  //      if (encodedPossibilities.contains(encoded)) continue;
  //      encodedPossibilities.add(encoded);
  //    }
  //    posAlongCutLoop = nposAlongCutLoop;
  //  }
  //}

  FastHPath introducePerturbation(FastHPath plan, int encodedPerturbation) {
    Pos joinPos = new Pos(encodedPerturbation % GRID_SIZE, (encodedPerturbation/GRID_SIZE) % GRID_SIZE);
    encodedPerturbation /= GRID_SIZE*GRID_SIZE;
    Pos cutPos = new Pos(encodedPerturbation % GRID_SIZE, (encodedPerturbation/GRID_SIZE) % GRID_SIZE);
    int[] cutQuadrantValues = getSortedPlanValues(plan.timingGrid, cutPos);
    int[] cutQuadrantPositions = getSortedPlanPositions(plan.timingGrid, cutQuadrantValues, cutPos);
    int[] joinQuadrantValues = getSortedPlanValues(plan.timingGrid, joinPos);
    int[] joinQuadrantPositions = getSortedPlanPositions(plan.timingGrid, joinQuadrantValues, joinPos);
    return introducePerturbation(plan, cutPos, cutQuadrantValues, cutQuadrantPositions, joinPos, joinQuadrantValues, joinQuadrantPositions);
  }

  FastHPath introducePerturbation(FastHPath plan, Pos cutPos, int[] cutQuadrantValues, int[] cutQuadrantPositions, Pos joinPos, int[] joinQuadrantValues, int[] joinQuadrantPositions) {
    int stepsFromHeadToCut = cutQuadrantValues[0];
    int stepsFromCutToJoin = joinQuadrantValues[2] - cutQuadrantValues[3];
    int loopStepsFromJoinToCut = cutQuadrantValues[2] - joinQuadrantValues[1];
    int loopStepsFromCutToJoin = joinQuadrantValues[0] - cutQuadrantValues[1];
    int stepsFromJoinToHead = GRID_SIZE*GRID_SIZE - joinQuadrantValues[3];
    //println("stepsFromHeadToCut :     ", stepsFromHeadToCut);
    //println("stepsFromCutToJoin :     ", stepsFromCutToJoin);
    //println("loopStepsFromJoinToCut : ", loopStepsFromJoinToCut);
    //println("loopStepsFromCutToJoin : ", loopStepsFromCutToJoin);
    //println("stepsFromJoinToHead :    ", stepsFromJoinToHead);
    //if (stepsFromHeadToCut+1+stepsFromCutToJoin+1+loopStepsFromJoinToCut+1+loopStepsFromCutToJoin+1+stepsFromJoinToHead != GRID_SIZE*GRID_SIZE) println("fdjjklmjjjjjjkljk");
    FastHPath newPlan = new FastHPath(plan.start);
    newPlan.cutPos = cutPos;
    newPlan.joinPos = joinPos;
    int moveId = 0;
    newPlan.moveCopy(plan, 0, moveId, stepsFromHeadToCut);
    moveId += stepsFromHeadToCut;
    newPlan.setTab(moveId, (byte)(dirAtoB(cutQuadrantPositions[0], cutQuadrantPositions[3])));
    moveId ++;
    newPlan.moveCopy(plan, cutQuadrantValues[3], moveId, stepsFromCutToJoin);
    moveId += stepsFromCutToJoin;
    newPlan.setTab(moveId, (byte)(dirAtoB(joinQuadrantPositions[2], joinQuadrantPositions[1])));
    moveId ++;
    newPlan.moveCopy(plan, joinQuadrantValues[1], moveId, loopStepsFromJoinToCut);
    moveId += loopStepsFromJoinToCut;
    newPlan.setTab(moveId, (byte)(dirAtoB(cutQuadrantPositions[2], cutQuadrantPositions[1])));
    moveId ++;
    newPlan.moveCopy(plan, cutQuadrantValues[1], moveId, loopStepsFromCutToJoin);
    moveId += loopStepsFromCutToJoin;
    newPlan.setTab(moveId, (byte)(dirAtoB(joinQuadrantPositions[0], joinQuadrantPositions[3])));
    moveId ++;
    newPlan.moveCopy(plan, joinQuadrantValues[3], moveId, stepsFromJoinToHead);
    newPlan.computeTimingGrid();
    return newPlan;
  }
  class OutputPlanProducer extends CutJoinConsumer {
    boolean consume(FastHPath plan, Pos cutPos, int[] cutQuadrantValues, int[] cutQuadrantPositions, Pos joinPos, int[] joinQuadrantValues, int[] joinQuadrantPositions) {
      output_plan = introducePerturbation(plan, cutPos, cutQuadrantValues, cutQuadrantPositions, joinPos, joinQuadrantValues, joinQuadrantPositions);
      return true;
    }
  }

  void show(Game g) {
    plan.computeTimingGrid();
    //showDebugPossibilitiesAlongPlan(g);

    noFill();
    stroke(255);
    strokeWeight(5);
    //plan.show(g.food, color(255), color(128), false);

    //if (!DO_DEBUG) return;
    if (mouseY < 100) {
      plan.show(g.food, color(255), color(64), false);
      //showDebugBlueBoxesAtPoses(g);
      showDebugRedGreen(g);
    } else showMousePlan(g);
    //showScores();
    //showMousePeturbations();
  }

  void showDebugRedGreen(Game g) {
    CutJoinConsumer consumer = new CutJoinConsumer() {
      boolean consume(FastHPath plan, Pos cutPos, int[] cutQuadrantValues, int[] cutQuadrantPositions, Pos joinPos, int[] joinQuadrantValues, int[] joinQuadrantPositions) {
        noStroke();
        fill(255, 0, 0, 64);
        ellipse(20*cutPos.x+10, 20*cutPos.y+10, 40, 40);
        fill(0, 255, 0, 64);
        ellipse(20*joinPos.x+10, 20*joinPos.y+10, 40, 40);
        return true;
      }
    };
    exploreShortcutPlan(g, plan, consumer, 1.0);
  }
  //void showDebugBlueBoxesAtPoses(Game g) {
  //  exploreCutsAlongPlanToGoal(plan, g.food, new CutConsumer() {
  //    void consume(Pos cutPos) {
  //      int food_time = plan.timingGrid[g.food.x][g.food.y];
  //      int[] cutQuadrantValues = getSortedPlanValues(plan.timingGrid, cutPos);
  //      if (cutQuadrantValues[0]+1 != cutQuadrantValues[1] || cutQuadrantValues[2]+1 != cutQuadrantValues[3]) return;
  //      if (cutQuadrantValues[3] > food_time) return;
  //      noStroke();
  //      fill(0, 0, 255, 64);
  //      rect(cutPos.x*20+10, cutPos.y*20+10, 30, 30, 5);
  //    }
  //  }
  //  );
  //}

  void showDebugPossibilitiesAlongPlan(Game g) {
    if (debug_encoded_possibilities_along_plan.length == 0) return;
    int id = floor(map(mouseX, 0, width+1, 0, debug_encoded_possibilities_along_plan.length));
    int encoding = debug_encoded_possibilities_along_plan[id];
    FastHPath planAlongPlan = introducePerturbation(debug_plan_after_food_update, encoding);
    strokeWeight(7);
    planAlongPlan.show(g.food, color(0, 0, 255), color(0, 0, 128), true);
  }

  void showMousePlan(Game g) {
    FastHPath newPlan;
    color col = color(255);
    if (debug_plans.length == 0) {
      newPlan = plan;
    } else {
      //int id = frameCount % debug_allpossibilities.length;
      int id = floor(map(mouseX, 0, width+1, 0, debug_plans.length));
      newPlan = debug_plans[id];
      col = debug_accepted[id] ? color(255) : color(128);
      noFill();
      strokeWeight(1);
      debug_plans_old[id].show(g.food, color(255), color(128, 30), false);
      strokeWeight(5);
    }
    newPlan.show(g.food, col, color(128, 30), false);

    noStroke();
    fill(255, 0, 0, 128);
    if (newPlan.cutPos != null) ellipse(20*newPlan.cutPos.x+10, 20*newPlan.cutPos.y+10, 40, 40);
    fill(0, 255, 0, 128);
    if (newPlan.joinPos != null) ellipse(20*newPlan.joinPos.x+10, 20*newPlan.joinPos.y+10, 40, 40);

    fill(255);
    text("energy : "+energy(g, newPlan), width/2-5, width-3);
  }

  void showMousePeturbations() {
    if (debug_interesting_perturbations.size() == 0) return;
    //int id = frameCount % debug_allpossibilities.length;
    int id = floor(map(mouseX, 0, width+1, 0, debug_interesting_perturbations.size()));
    int encoded = debug_interesting_perturbations.get(id);
    Pos joinPos = new Pos(encoded % GRID_SIZE, (encoded/GRID_SIZE) % GRID_SIZE);
    encoded /= GRID_SIZE*GRID_SIZE;
    Pos cutPos = new Pos(encoded % GRID_SIZE, (encoded/GRID_SIZE) % GRID_SIZE);
    strokeWeight(2);
    noStroke();
    fill(255, 0, 0, 128);
    ellipse(20*cutPos.x+10, 20*cutPos.y+10, 40, 40);
    fill(0, 255, 0, 128);
    ellipse(20*joinPos.x+10, 20*joinPos.y+10, 40, 40);
  }

  void showScores() {
    if (debug_energy.length == 0) return;
    pushMatrix();
    translate(0, height);
    scale(1, -1);
    int w = debug_energy.length;
    float h = 100;
    //for (int i = 0; i < w; i++) h = max(h, debug_scores[i]);
    float xmul = float(width)/w;
    float ymul = float(height)/h;
    strokeWeight(1);
    stroke(255);
    for (int i = 0; i < w; i++) {
      line(i*xmul, debug_energy[i]*ymul, (i+1)*xmul, debug_energy[i]*ymul);
      line(i*xmul, debug_energy_record[max(0, i-1)]*ymul, (i+1)*xmul, debug_energy_record[i]*ymul);
    }
    popMatrix();
  }
}
