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
     totalBomb:3,bombLevel:1,puttAble:true,prevFire:false,pushBombAble:false,totalSpecial:0});
actor.gotoAndStop("down");
actor.body.stop();
_parent.heroObj1={life:3,totalBomb:3,score:0,killScore:0,totalScore:0};
_parent.heroObj2={life:1,totalBomb:3,score:0,killScore:0,totalScore:0};
var sentinel=brickArea.attachMovie("hero2","hero2",100);
sentinel.heroNum=2;sentinel.heroId=2;sentinel.life=1;sentinel.moving=true;
sentinel.varShield=99999;sentinel.slowTime=-1;sentinel._x=0;sentinel._y=0;
sentinel.totalBomb=3;sentinel.puttAble=true;sentinel.bombLevel=1;
for(var i=0;i<fixture.bombs.length;i++) {
    var spec=fixture.bombs[i];var hero=brickArea["hero"+spec.owner];
    var oldX=hero.x;var oldY=hero.y;hero.x=spec.cell[0];hero.y=spec.cell[1];
    if(!putBomb(hero)) trace("CORE_ERROR|Initial bomb rejected");
    brickArea["bomb"+hero.y+"_"+hero.x].delayTime=spec.fuse;
    hero.x=oldX;hero.y=oldY;
}
if(fixture.pulse!=null) addBrickExp(fixture.pulse[0],fixture.pulse[1],2);
if(fixture.weapon!=null) {
    sentinel.x=fixture.weapon.cell[0];sentinel.y=fixture.weapon.cell[1];
    sentinel.moving=false;sentinel.totalSpecial=3;sentinel.gotoAndStop(3);
    sentinel.specialToolName=fixture.weapon.kind=="rocket" ? "火箭" : "火焰箭";
    if(!putSpecial(sentinel)) trace("CORE_ERROR|Initial special rejected");
    sentinel.x=0;sentinel.y=0;sentinel.moving=true;
}
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
    var bombs="";var energies="";
    for(var y=0;y<h;y++) for(var x=0;x<w;x++) {
        var cell=bgArea["bg"+y+"_"+x];
        if(cell.bomb!="") {
            var bomb=brickArea[cell.bomb];bombs+=x+","+y+","+bomb.heroNum+","+bomb.delayTime+";";
        }
        if(cell.expEnergy>0) energies+=x+","+y+","+cell.expEnergy+","+cell.expHeroNum+";";
    }
    trace("CORE_SAMPLE|"+tick+"|"+actor.x+"|"+actor.y+"|"+actor.moving
        +"|"+(actor.moving ? actor.vLevel-actor.movId : 0)+"|"+actor.prevFire+"|"+actor.puttAble
        +"|"+_parent.heroObj1.totalBomb+"|"+_parent.heroObj2.totalBomb+"|"+bombs+"|"+energies);
};
