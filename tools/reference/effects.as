// Fixed presentation fixtures; all original functions and symbol scripts remain.
stop(); Stage.scaleMode = "noScale"; Stage.align = "TL";
game = this; w = 15; h = 13; d = 30; pausing = false; totalPlayer = 1;
xy = [[-1,0],[0,-1],[1,0],[0,1]];
createEmptyMovieClip("bgArea",1); createEmptyMovieClip("brickArea",2);
brickArea.margin = 10;
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
var hero=brickArea.attachMovie("hero1","hero1",3000,{x:8,y:6,_x:240,_y:180,heroNum:1,heroId:Number(scenario.substr(5)),totalBomb:1,bombLevel:3});
hero._visible=false;
if(scenario=="bomb") {
    hero.heroId=1; putBomb(hero);
} else if(scenario.substr(0,5)=="flame") {
    putBomb(hero); bombExp(bgArea.bg6_8);
} else if(scenario=="brick") {
    brickArea.attachMovie("brickExp","brickExp6_8",calDepth(8,6,10),{_x:240,_y:180});
} else {
    var i=0;
    while(i<6) {
        var tool=brickArea.attachMovie("tool","tool"+i,100+i,{_x:60+i*60,_y:210});
        tool.tool_mc.gotoAndStop(i+1);
        i++;
    }
}
function observe() {
    var values=[];
    if(scenario=="pickups") {
        var i=0;
        while(i<6) {
            var tool=brickArea["tool"+i];
            values.push(tool==undefined?0:tool.tool_mc._currentframe);
            values.push(tool==undefined?0:Math.round(tool.tool_mc._y*20));
            values.push(tool==undefined?0:Math.round(tool.tool_mc._alpha*256/100));
            i++;
        }
    } else if(scenario=="brick") {
        var clip=brickArea.brickExp6_8;
        values.push(clip==undefined?0:clip._currentframe);
    } else {
        var bomb=brickArea.bomb6_8;
        var blast=bgArea.expArea6_8;
        values.push(bomb==undefined?0:bomb._currentframe);
        values.push(blast==undefined?0:Math.round(blast._alpha*256/100));
        values.push(blast==undefined?0:blast.expXy.length);
    }
    trace("EFFECT_SAMPLE|"+tick+"|"+values.join(","));
}
tick=-1; observe();
this.onEnterFrame=function() {
    tick++;
    if(scenario=="pickups" && tick==85) {
        var i=0;
        while(i<6) { brickArea["tool"+i].gotoAndPlay("remove"); i++; }
    }
    observe();
};
