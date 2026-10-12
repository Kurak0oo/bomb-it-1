// Original clip timelines, isolated from gameplay eligibility and callbacks.
stop(); Stage.scaleMode="noScale"; Stage.align="TL";
var kind=scenario.split("-")[0];
var direction=Number(scenario.split("-")[1]);
var names={rocket:"rocket",grenade:"grenade",mine:"mine",gas:"gasBomb",ice:"freezeEffect",fire:"fireEffect"};
if(scenario=="impact") {
    game=this; w=15; h=13; d=30; pausing=false; totalPlayer=1;
    xy=[[-1,0],[0,-1],[1,0],[0,1]];
    createEmptyMovieClip("bgArea",1); createEmptyMovieClip("brickArea",2); brickArea.margin=10;
    var y=0;
    while(y<h) {
        var x=0;
        while(x<w) {
            var bg=bgArea.createEmptyMovieClip("bg"+y+"_"+x,y*w+x);
            bg.x=x; bg.y=y; bg.brick=""; bg.bomb=""; bg.tool=""; bg.expEnergy=0;
            x++;
        }
        y++;
    }
    bgArea.bg6_9.brick="breakAble";
    var hero=brickArea.attachMovie("hero1","hero1",3000,{x:8,y:6,_x:240,_y:180,heroNum:1,heroId:1,totalSpecial:1,specialToolName:"火箭"});
    hero._visible=false; hero.gotoAndStop(3); putSpecial(hero);
} else {
    var clip=attachMovie(names[kind],"effect",1,{_x:240,_y:180});
    if(kind=="rocket" || kind=="grenade") { clip.gotoAndStop(direction+1); }
}
function observe() {
    var c=scenario=="impact"?brickArea.rocket6_8:this.effect;
    var nested=0;
    for(var name in c) { if(typeof(c[name])=="movieclip") { nested=c[name]._currentframe; } }
    var smoke=0;
    if(scenario=="impact") { for(var name in bgArea) { if(name.substr(0,11)=="rocketSmoke") { smoke++; } } }
    trace("EFFECT_SAMPLE|"+tick+"|"+(c==undefined?0:1)+","+(c==undefined?0:c._currentframe)+","+nested+","+smoke);
}
tick=-1; observe();
this.onEnterFrame=function() { tick++; observe(); };
