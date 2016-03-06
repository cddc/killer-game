<?php 
print "<html>";
print "<head> <meta http-equiv=Content-Type content='text/html;charset=utf-8'><title>游戏规则</title>";
print "<body>";
$str = " 【黄草梁杀人游戏 v0.0.1】 - 内测使用，感谢大家协助

1. 指令“当前状态”，可随时使用，用于查看当前游戏名称，状态（是否开始，以及游戏中状态），参与人数等。

2. 指令“用户列表”，可在报名之后所有环节使用，查看已进游戏的人员情况（昵称，状态。未分配确认时以减号'-'显示）

3. 游戏状态大致分几个环节：
 1). 报名: 本环节专用指令“地振高罡”
      未报名时处于禁聊状态（防打搅），报名后进入匿名群聊频道（未分配昵称，所以匿名）。
      报名截止条件：到达设置的截止时间之后，报名人数达到最低要求（5人）。或者任何时候报名人数达到最高上限（10人）
      报名截止时：系统主动分配和公布所有人的游戏昵称和游戏角色，并提示进入'确认'流程。

 2). 确认:本环节专用指令“确认”
      用户看清楚自己的角色和昵称后，回复确认。
      系统会一直等待所有人完成确认，才会进入天黑流程（这里如果有人放鸽子，怎么办？没想好，大家看）

 3). 天黑: 本环节专用指令“杀XX”和“验XX”
      所有杀手会临时进入杀手群聊频道，警察也有警察频道，互不干扰，共同协商。其他人禁聊
      杀手商量好后，发指令“杀XX”，该指令可多发，以最后一次为准
      警察商量好后，发指令“验XX”，该指令因会立即返回结果，故仅能发一次。返回结果之后，指令不再可用。
      系统会一直等待杀手和警察完成相关动作，才会天亮（这里如果有人放鸽子，怎么办？没想好，大家看）

 4). 遗言：本环节专用指令“遗言结束”
      （游戏有几个杀手就设置几轮遗言，这个规则没错吧？）
      所有人禁聊。仅濒死者独享群聊频道，慢慢说，说完发指令结束，然后系统天亮。
      (这里如果濒死者一直话痨，怎么办？没想好，大家看)
 
 5). 天亮:
      系统公告天亮和投票时间点，死者禁聊，其他人进入群聊频道，好好聊，直到到达投票时间点.

 6). 投票: 本环节专用指令“投XX”
      所有人禁聊，专心投票。可重复投，以最后为准。到达投票截止时间且所有人都投票后，投票才结束。
      （这里如果有人投票也鸽子，怎么办？没想好，大家看）
     投票结束后，系统会公布投票结果，并决定应该进入哪个环节。
       （票死的无遗言。没意见吧？反正我也没打算开发这个功能）

 7). 对辩:
      当投票出现票数相等时，进入对辩。其他人禁聊，几个倒霉蛋进群聊频道开始PK。
      PK无发言顺序和规则，直接吵架即可，也可沉默。
      对辩时间截止之后，再次投票

 8). 结束：
      当杀手胜利或警民胜利后，系统出公告，所有人都进群聊，可以讨论和复盘。
      （后续考虑，可以把游戏过程记录直接推送到网站上，方便大家复盘讨论）
";
print "<div style='align:auto'>";
print implode("<br>", explode("\n", $str));
print "</div>";


print "<hr>";
$str = "Right Here Waiting For You
 
Oceans apart, day after day, 
and I slowly go insane. 
I hear your voice on the line,
But it doesn't stop the pain. 
If I see you next to never, 
How can we say forever? 
Wherever you go, whatever you do, 
I will be right here waiting for you; 
Whatever it takes,
Or how my heart breaks, 
I will be right here waiting for you. 
I took for granted all the times 
That I thought would last somehow. 
I hear the laughter, 
I taste the tears, 
But I can't get near you now. 
Oh, can't you see it , baby, 
You've got me going crazy? 
Wherever you go, whatever you do,
I will be right here waiting for you; 
Whatever it takes, or how my heart breaks,
I will be right here waiting for you. 
I wonder how we can survive this romance.
But in the end If I'm with you 
I'll take the chance. 
Oh, can't you see it, baby, 
You've got me going crazy? 
Wherever you go, whatever you do, 
I will be right here waiting for you. 
Whatever it takes
Or how my heart breaks,
I will be right here waiting for you.
Waiting for you.
";
print "<div style='align:auto'>";
print implode("<br>", explode("\n", $str));
print "</div>";

print "</body></html>";
?>
