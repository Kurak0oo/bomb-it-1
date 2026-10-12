// Controlled setup, input injection and observation only. Both polling and
// key-up functions below were installed by the unchanged frame-2 DoAction tag.
stop();
Stage.scaleMode = "noScale";
Stage.align = "TL";
var originalPoll = this.onEnterFrame;
var originalRelease = this.onKeyUp;
if (typeof(originalPoll) != "function" || typeof(originalRelease) != "function") {
    trace("CORE_ERROR|Original frame-2 callbacks missing");
}
var fixture;
for (var i = 0; i < configuration.scenarios.length; i++) {
    if (configuration.scenarios[i].name == scenario) fixture = configuration.scenarios[i];
}
if (fixture == undefined) trace("CORE_ERROR|Unknown scenario");
w = 15;
h = 13;
d = 30;
xy = [[-1,0],[0,-1],[1,0],[0,1]];
totalPlayer = 1;
pausing = false;
brickArea.margin = 10;
for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
        var cell = bgArea.createEmptyMovieClip("bg" + y + "_" + x, y * w + x);
        cell.x=x; cell.y=y; cell.brick=""; cell.bomb=""; cell.tool="";
        cell.expEnergy=0; cell.expHeroNum=0;
    }
}
p1 = {key0:37,key1:38,key2:39,key3:40,fireKey:32};
var actor = brickArea.attachMovie("hero1", "hero1", calDepth(fixture.cell[0],fixture.cell[1],10)-1,
    {x:fixture.cell[0],y:fixture.cell[1],_x:fixture.cell[0]*d,_y:fixture.cell[1]*d,
     heroNum:1,heroId:1,life:3,varShield:999,shield:false,
     moving:false,movId:0,vLevel:6,slowTime:-1,slowVLevel:20,stopTime:0,
     totalBomb:3,bombLevel:1,puttAble:true,prevFire:false,pushBombAble:true,totalSpecial:0});
actor.gotoAndStop(fixture.facing+1);
actor.body.stop();
if(configuration.profile == "push-v1" || configuration.profile == "grenade-v1") _parent.heroObj1={life:3,totalBomb:3,score:0,killScore:0,totalScore:0};
if (fixture.weapon == "grenade") {
    actor.totalSpecial=3;
    actor.specialToolName="手榴弹";
}
// Keep the original outcome branch inactive, without replacing gameover or AI.
// This far-away enemy is permanently moving and has no movement callback.
var sentinel = brickArea.createEmptyMovieClip("hero2",100);
sentinel.heroNum=2; sentinel.heroId=2; sentinel.life=1; sentinel.moving=true;
sentinel.varShield=99999; sentinel.slowTime=-1; sentinel._x=0; sentinel._y=0;
for (var i=0; i<fixture.walls.length; i++) {
    var at=fixture.walls[i]; bgArea["bg"+at[1]+"_"+at[0]].brick="unbreakAble";
}
for (var i=0; i<fixture.bricks.length; i++) {
    var at=fixture.bricks[i]; bgArea["bg"+at[1]+"_"+at[0]].brick="fixtureBrick";
}
if (fixture.bomb != null) {
    actor.x=fixture.bomb[0]; actor.y=fixture.bomb[1];
    putBomb(actor);
    var initial=bgArea["bg"+actor.y+"_"+actor.x];
    brickArea[initial.bomb].delayTime=fixture.fuse;
    if (fixture.prepush) pushBomb(initial,1,0);
    actor.x=fixture.cell[0]; actor.y=fixture.cell[1];
}
if (fixture.initial_grenade) putSpecial(actor);
if (fixture.energy != null) addBrickExp(fixture.energy[0],fixture.energy[1],1);
// A fixture input adapter, not a copy of the game's polling or release logic.
// The original callbacks call these Key APIs unchanged.
var directionInput=-1;
var fireInput=false;
Key = {isDown:function(code) {
    return code == 32 ? fireInput : directionInput >= 0 && code == p1["key"+directionInput];
},getCode:function() { return 32; }};
var tick=-1;
this.onEnterFrame = function() {
    tick++;
    if (tick >= fixture.commands.length) return;
    var command=fixture.commands[tick];
    var released=fireInput && !command[1];
    directionInput=command[0];
    fireInput=command[1];
    if (released) originalRelease.call(this);
    originalPoll.call(this);
    var activeBomb;
    var reservationX=-1; var reservationY=-1;
    var energies=""; var occupancy=""; var bricks="";
    for (var y=0; y<h; y++) {
        for (var x=0; x<w; x++) {
            var bg=bgArea["bg"+y+"_"+x];
            if (bg.expEnergy>0) energies+=x+","+y+","+bg.expEnergy+";";
            if (bg.brick!="") bricks+=x+","+y+";";
            if (bg.bomb!="") {
                occupancy+=x+","+y+";";
                activeBomb=brickArea[bg.bomb]; reservationX=x; reservationY=y;
            }
        }
    }
    var grenade=brickArea["grenade"+fixture.cell[1]+"_"+fixture.cell[0]];
    var hasBomb=activeBomb != undefined;
    var hasGrenade=grenade != undefined;
    var remaining=hasBomb && (activeBomb.x!=reservationX || activeBomb.y!=reservationY) ? 2-activeBomb.movId : 0;
    trace("CORE_SAMPLE|"+tick+"|"+actor.x+"|"+actor.y+"|"+actor.moving
        +"|"+hasBomb+"|"+(hasBomb ? activeBomb.x : -1)+"|"+(hasBomb ? activeBomb.y : -1)
        +"|"+reservationX+"|"+reservationY
        +"|"+(hasBomb ? Math.round(activeBomb._x*20) : -1)+"|"+(hasBomb ? Math.round(activeBomb._y*20) : -1)
        +"|"+(hasBomb ? activeBomb.delayTime : -1)+"|"+remaining
        +"|"+hasGrenade+"|"+(hasGrenade ? fixture.cell[0] : -1)+"|"+(hasGrenade ? fixture.cell[1] : -1)
        +"|"+(hasGrenade ? grenade.x : -1)+"|"+(hasGrenade ? grenade.y : -1)+"|"+(hasGrenade ? grenade.body._currentframe : 0)
        +"|"+(hasGrenade ? Math.round(grenade._x*20) : -1)+"|"+(hasGrenade ? Math.round(grenade._y*20) : -1)
        +"|"+actor.totalSpecial+"|"+actor.puttAble+"|"+energies+"|"+occupancy+"|"+bricks
        +((configuration.profile == "push-v1" || configuration.profile == "grenade-v1") ? "|"+actor.totalBomb : ""));
};
