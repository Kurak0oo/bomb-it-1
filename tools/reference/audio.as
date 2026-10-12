// Observer delegates every Sound operation to the native original API.
// Sprite 564 functions and child callbacks retain their original bytecode.
stop();
var scenario = _parent.scenario;
var tick = -1;
var attachNative = Sound.prototype.attachSound;
var startNative = Sound.prototype.start;
var stopNative = Sound.prototype.stop;
ASSetPropFlags(Sound.prototype,"attachSound,start,stop",0,4);
Sound.prototype.attachSound = function(name) { this.observedName=name; return attachNative.apply(this,arguments); };
Sound.prototype.start = function() { trace("AUDIO|"+tick+"|start|"+this.observedName); return startNative.apply(this,arguments); };
Sound.prototype.stop = function() { trace("AUDIO|"+tick+"|stop|"+this.observedName); return stopNative.apply(this,arguments); };
game=this; w=15; h=13; d=30; pausing=false; totalPlayer=1; brickScore=10;
xy=[[-1,0],[0,-1],[1,0],[0,1]];
_parent.soundon=true; _parent.heroObj1={totalBomb:4,score:0,brickScore:0};
_parent.allPan={upDate:function(){}};
createEmptyMovieClip("bgArea",1); createEmptyMovieClip("brickArea",2); brickArea.margin=10;
createEmptyMovieClip("vo_mc",3); vo_sound=new Sound(vo_mc);
for(var y=0;y<h;y++) for(var x=0;x<w;x++) {
    var bg=bgArea.createEmptyMovieClip("bg"+y+"_"+x,y*w+x);
    bg.x=x;bg.y=y;bg.brick="";bg.bomb="";bg.tool="";bg.expEnergy=0;
}
var hero=brickArea.attachMovie("hero1","hero1",3000,{x:6,y:6,_x:180,_y:180,heroNum:1,heroId:1,totalBomb:4,bombLevel:1,totalSpecial:3,puttAble:true});
hero.gotoAndStop(3);
var names={rocket:"火箭",mine:"地雷",gas:"汽弹",grenade:"手榴弹",fire:"火焰箭",ice:"冰箭"};
if(scenario=="single" || scenario=="double") {
    vo_sound.attachSound("exp.wav");vo_sound.start();
    if(scenario=="double") vo_sound.start();
} else if(scenario=="overlap") {
    vo_sound.attachSound("exp.wav");vo_sound.start();vo_sound.start();
    vo_sound.attachSound("putBomb.wav");vo_sound.start();
} else if(scenario=="bombs") {
    putBomb(hero);hero.x=9;hero._x=270;putBomb(hero);
    bombExp(bgArea.bg6_6);bombExp(bgArea.bg6_9);
} else if(scenario=="push") {
    putBomb(hero);pushBomb(bgArea.bg6_6,1,0);
} else if(scenario=="pickup") {
    hero.vLevel=6;hero.slowTime=-1;
    var item=brickArea.attachMovie("tool","tool6_7",3001,{toolName:"盾牌"});
    bgArea.bg6_7.tool="tool6_7";movHero(hero,2);
} else if(scenario=="muted") {
    _parent.soundon=false;putBomb(hero);bombExp(bgArea.bg6_6);
} else if(scenario=="shuffle") {
    var tracks=[1,2,3,4];trace("BEFORE|"+tracks.join(","));
    for(var j=0;j<100;j++){disorder(tracks);trace("ORDER|"+tracks.join(","));}
} else {
    var kind=scenario.split("-")[0];hero.specialToolName=names[kind];
    if(scenario=="fire-brick" || scenario=="rocket-brick") bgArea.bg6_7.brick="breakAble";
    if(scenario=="rocket-wall") bgArea.bg6_7.brick="unbreakAble";
    putSpecial(hero);
    if(kind=="mine") bgArea.bg6_6.expEnergy=1;
}
this.onEnterFrame=function(){tick++;if(tick==30){trace("AUDIO_DONE");delete this.onEnterFrame;}};
