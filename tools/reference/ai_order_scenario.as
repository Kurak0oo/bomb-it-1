// Controlled setup, input injection and observation only. Both polling and
// key-up functions come from frame 2; only its RandomNumber opcodes are adapted.
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
var actor = brickArea.attachMovie("hero2", "hero2", calDepth(8,6,10)-1,
    {x:8,y:6,_x:8*d,_y:6*d,
     heroNum:2,heroId:2,life:3,varShield:999,shield:false,
     moving:false,movId:0,vLevel:6,slowTime:-1,slowVLevel:20,stopTime:0,
     totalBomb:3,bombLevel:1,puttAble:true,prevFire:false,pushBombAble:false,totalSpecial:0});
actor.gotoAndStop("down");
actor.body.stop();
var weaponNames={rocket:"火箭",mine:"地雷",gas:"汽弹",grenade:"手榴弹",fire:"火焰箭",ice:"冰箭"};
if (fixture.weapon != "bomb") {
    actor.totalSpecial=3;
    actor.specialToolName=weaponNames[fixture.weapon];
}
for(var i=0;i<fixture.walls.length;i++) {
    var at=fixture.walls[i];bgArea["bg"+at[1]+"_"+at[0]].brick="unbreakAble";
}
_parent.heroObj2={life:3,totalBomb:3,score:0,killScore:0,totalScore:0};
// Keep the original outcome branch inactive, without replacing gameover or AI.
// This far-away enemy is permanently moving and has no movement callback.
var sentinel = brickArea.createEmptyMovieClip("hero1",100);
sentinel.heroNum=1; sentinel.heroId=1; sentinel.life=1; sentinel.moving=true;
sentinel.varShield=99999; sentinel.slowTime=-1; sentinel._x=0; sentinel._y=0;
// A fixture input adapter, not a copy of the game's polling or release logic.
// The original callbacks call these Key APIs unchanged.
var randomTape=[99,0,3];var randomIndex=0;
function fixtureRandom(limit) {
    if(randomIndex>=randomTape.length) {trace("CORE_ERROR|Unexpected AI random call");return 0;}
    var value=randomTape[randomIndex++];

    if(value>=limit) trace("CORE_ERROR|AI random tape out of range");
    return value;
}
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
    if(randomIndex != 3) trace("CORE_ERROR|Expected exactly three AI decisions");
    var bombs="";var specials=[];
    var prefixes={rocket:"rocket",mine:"mine",grenade:"grenade",gas:"gasBomb"};
    for(var y=0;y<h;y++) for(var x=0;x<w;x++) {
        var name=y+"_"+x;var bomb=brickArea["bomb"+name];
        if(bomb!=undefined) bombs+=x+","+y+","+bomb.delayTime+";";
        for(var kind in prefixes) {
            var weapon=brickArea[prefixes[kind]+name];
            if(weapon!=undefined) {
                var facing=weapon._currentframe-1;
                var dx=(kind=="rocket"||kind=="grenade") ? xy[facing][0] : 0;
                var dy=(kind=="rocket"||kind=="grenade") ? xy[facing][1] : 0;
                specials.push(kind+","+x+","+y+","+dx+","+dy+";");
            }
        }
    }
    for(var key in bgArea) {
        var weapon=bgArea[key];
        if(typeof(weapon)=="movieclip") {
            var kind=weapon._name.indexOf("fireArea")==0 ? "fire" : weapon._name.indexOf("iceArea")==0 ? "ice" : "";
            if(kind!="") specials.push(kind+","+weapon.x+","+weapon.y+","+weapon.dx+","+weapon.dy+";");
        }
    }
    specials.sort();
    trace("CORE_SAMPLE|"+tick+"|"+actor.x+"|"+actor.y+"|"+(actor._currentframe-1)
        +"|"+actor.moving+"|"+(actor.moving ? actor.vLevel-actor.movId : 0)
        +"|"+actor.prevFire+"|"+actor.puttAble+"|"+actor.totalBomb+"|"+actor.totalSpecial
        +"|"+bombs+"|"+specials.join(""));
};
