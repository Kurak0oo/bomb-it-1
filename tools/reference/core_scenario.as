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
     heroNum:1,heroId:1,life:3,varShield:fixture.shield,shield:fixture.armor,
     moving:false,movId:0,vLevel:6,slowTime:-1,slowVLevel:20,stopTime:0,
     totalBomb:3,bombLevel:1,puttAble:true,prevFire:false,pushBombAble:false,totalSpecial:0});
actor.gotoAndStop("down");
actor.body.stop();
if (fixture.weapon == "mine") {
    actor.totalSpecial=3;
    actor.specialToolName="地雷";
}
// Keep the original outcome branch inactive, without replacing gameover or AI.
// This far-away enemy is permanently moving and has no movement callback.
var sentinel = brickArea.createEmptyMovieClip("hero2",100);
sentinel.heroNum=2; sentinel.heroId=2; sentinel.life=1; sentinel.moving=true;
sentinel.varShield=99999; sentinel.slowTime=-1; sentinel._x=0; sentinel._y=0;
var origin = fixture.explosion == null ? [8,6] : fixture.explosion;
if (fixture.explosion != null) {
    var bg = bgArea["bg"+origin[1]+"_"+origin[0]];
    bg.bomb="bomb"+origin[1]+"_"+origin[0];
    brickArea.attachMovie("bomb",bg.bomb,5000,{x:origin[0],y:origin[1],_x:origin[0]*d,_y:origin[1]*d,heroNum:1,heroId:1,bombLevel:1});
    bombExp(bg);
    actor.totalBomb=3;
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
    var bombs="";
    var mines="";
    for (var y=0; y<h; y++) {
        for (var x=0; x<w; x++) {
            var name=y+"_"+x;
            var bomb=brickArea["bomb"+name];
            if (bomb != undefined) bombs+=x+","+y+","+bomb.delayTime+";";
            if (brickArea["mine"+name] != undefined) mines+=x+","+y+";";
        }
    }
    trace("CORE_SAMPLE|"+tick+"|"+actor.x+"|"+actor.y
        +"|"+Math.round(actor._x*20)+"|"+Math.round(actor._y*20)
        +"|"+Math.round(actor._x/d)+"|"+Math.round(actor._y/d)
        +"|"+actor.moving+"|"+(actor.moving ? actor.vLevel-actor.movId : 0)
        +"|"+actor.prevFire+"|"+actor.puttAble+"|"+actor.totalBomb+"|"+bombs
        +"|"+actor.totalSpecial+"|"+mines+"|"+actor.life+"|"+actor.shield+"|"+actor.varShield
        +"|"+bgArea["bg"+origin[1]+"_"+origin[0]].expEnergy+"|"+bgArea.bg6_9.expEnergy);
};
