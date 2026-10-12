stop();
game = this;
totalPlayer = _parent.totalPlayer;
createEmptyMovieClip("brickArea",1);
var i = 1;
while(i <= totalPlayer) {
 var hero = brickArea.createEmptyMovieClip("hero"+i,i);
 hero.heroNum = i;
 hero.heroId = i;
 i++;
}
attachMovie("fixtureBanner","youWin",2,{_x:222.75,_y:189.5});
this.onEnterFrame = function() {
 _parent.started = getTimer();
 gameover("win");
};
