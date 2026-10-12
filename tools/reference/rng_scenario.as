// Random boundary and observations only. Original frame 1/2 execute in Sprite564.
stop();
var desiredScene=Number(scene);
var phase="initial";
var calls=0;
var dropTape=[];
var dropIndex=0;
var pendingFrame=0;
function fixtureRandom(bound,site) {
    var value;
    if(phase.indexOf("drop-")==0 || phase=="shuffle-boundary") {
        if(dropIndex>=dropTape.length) trace("RNG_ERROR|drop recording exhausted");
        value=dropTape[dropIndex++];
    } else if(bound==5) value=desiredScene;
    else value=random(bound);
    if(value<0 || value>=bound || value==undefined) trace("RNG_ERROR|invalid random result");
    trace("RNG_CALL|"+phase+"|"+(calls++)+"|"+site+"|"+bound+"|"+value);
    return value;
}
function snapshot(kind) {
    var g=game;
    var shields=[];
    for(var id=1;id<=4;id++) shields.push(g.brickArea["hero"+id].varShield);
    trace("RNG_META|"+phase+"|"+kind+"|"+g.sceneStyle+"|"+g.bgArea.bg0_0._currentframe+"|"+g.brickArea.brick5_6._currentframe+"|"+g.brickStyle.join(",")+"|"+specialToolName_array.join(",")+"|"+specialToolId+"|"+bgMusic_array.join(",")+"|"+bgMusicId+"|"+stageNum+"|"+shields.join(","));
    for(var y=0;y<13;y++) for(var x=0;x<15;x++) {
        var bg=g.bgArea["bg"+y+"_"+x];
        var value=bg.brick=="unbreakAble" ? 2 : (bg.brick=="" ? 0 : 1);
        var brick=g.brickArea["brick"+y+"_"+x];
        var style=value==0 ? 0 : brick._currentframe;
        if(style==undefined) style=0;
        trace("RNG_CELL|"+phase+"|"+kind+"|"+x+"|"+y+"|"+value+"|"+style);
    }
}
function roundReady() {
    snapshot("population");
    if(phase=="initial") {
        var choices=[[99],[0,0,0],[0,0,1],[0,0,15],[0,0,40],[0,0,50],[0,0,75],[0,99,0],[0,99,1]];
        for(var n=0;n<choices.length && !rawControl;n++) {
            phase="drop-"+n;dropTape=choices[n];dropIndex=0;
            var bg=undefined;
            for(var y=0;y<13;y++) {for(var x=0;x<15;x++) {
                var candidate=game.bgArea["bg"+y+"_"+x];
                if(candidate.brick!="" && candidate.brick!="unbreakAble") {bg=candidate;break;}
            } if(bg!=undefined) break;}
            game.brickBreak(bg,1);
            var tool=game.brickArea[bg.tool];
            trace("RNG_DROP|"+n+"|"+bg.x+"|"+bg.y+"|"+(tool==undefined ? "" : tool.toolName));
            if(dropIndex!=dropTape.length) trace("RNG_ERROR|unconsumed drop recording");
        }
        phase="retry";
        pendingFrame=2;
    } else if(phase=="retry") {
        phase="stage2";
        pendingFrame=1;
    } else if(phase=="stage2") {
        phase="stage3";
        pendingFrame=1;
    } else if(phase=="stage3") {
        phase="stage4";
        pendingFrame=1;
    } else {
        game.stop();
        if(!rawControl) {
            phase="shuffle-boundary";dropTape=[3,1,2,3];dropIndex=0;
            var boundary=[1,2,3,4];game.disorder(boundary);
            trace("RNG_SHUFFLE|boundary|1,2,3,4|"+boundary.join(","));
        }
        phase="shuffle-random";
        var tracks=[1,2,3,4];
        for(var count=0;count<100;count++) {
            var before=tracks.join(",");game.disorder(tracks);
            trace("RNG_SHUFFLE|"+count+"|"+before+"|"+tracks.join(","));
        }
        trace("RNG_DONE");
    }
}
varHard="normal";soundon=false;totalPlayer=1;stageNum=0;
specialToolName_array=["火箭","地雷","手榴弹","汽弹","冰箭","火焰箭"];specialToolId=6;
bgMusic_array=["Bombit_-_level_1","Bombit_-_level_2","Bombit_-_level_3","Bombit_-_level_4"];bgMusicId=4;
p1={heroId:1,key0:37,key1:38,key2:39,key3:40,fireKey:32};
for(var id=1;id<=4;id++) this["heroObj"+id]={heroId:0,life:id==1?3:1,totalScore:0};
allPan={init:function(){},upDate:function(){},showMc:function(){}};
timer={timeInit:function(){},timeStart:function(){}};
upDateStageNum=function(value){};pause_btn={};music_btn={};
attachMovie("fixtureRngGame","game",1);
this.onEnterFrame=function(){if(pendingFrame>0 && game._currentframe==3){var target=pendingFrame;pendingFrame=0;game.gotoAndPlay(target);}};
