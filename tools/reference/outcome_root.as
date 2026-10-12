stop();
Stage.scaleMode = "noScale";
Stage.align = "TL";
soundon = false;
totalPlayer = Number(players);
if(totalPlayer != 2) { totalPlayer = 1; }
stageNum = 1;
totalStage = 20;
varHard = "normal";
var i = 1;
while(i <= 4) {
 this["heroObj"+i] = {heroId:i,life:3,killScore:1000,brickScore:10,toolScore:100,timeScore:0,bonus:0,score:1110,totalScore:2110};
 i++;
}
createEmptyMovieClip("timer",1);
timer.t = 100;
timer.timeStop = function() {};
createEmptyMovieClip("allPan",2);
allPan.upDate = function() {};
attachMovie("fixtureScores","stageScore",30,{_x:275,_y:200});
attachMovie("fixtureGame","game",10,{_x:93.1,_y:5.2});
this.onEnterFrame = function() {
 if(started) {
  trace("OUTCOME_SAMPLE|"+(getTimer()-started)+"|"+game.youWin._currentframe+"|"+stageScore._currentframe+"|"+heroObj1.score+"|"+stageScore.score1+"|"+heroObj1.totalScore);
 }
};
