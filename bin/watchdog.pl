#!/usr/bin/perl
use 5.016;
use strict;
use warnings;
use utf8;
use POSIX;
use Encode;
use IO::Socket;
use IO::Select;

#binmode(STDIN,  ":encoding(utf8)");
#binmode(STDOUT, ":encoding(utf8)");
#binmode(STDERR, ":encoding(utf8)");
$|=1;
chomp(my $WORK_DIR=`echo \$(cd \$(dirname $0)/..; pwd)`);
my $DATA_DIR="$WORK_DIR/data";

#my @NAME_LIST=('郭靖','黄蓉','念慈','华筝','七公','一灯','东邪','西毒','杨康','梅超风','周伯通','丘处机','王重阳','杨过','小龙女','郭襄','李莫愁','郭芙');
my @NAME_LIST=('乔峰','段誉','语嫣','虚竹','阿朱','梦姑','阿紫','木婉清','童姥','钟灵','丁春秋','李秋水','无崖子','张纪中');
my %USER_ROLES=(
	2 => { roles=>{KILLER=>{name=>'杀手', num=>1}, PROBER=>{name=>'警察', num=>1}, SHEEP=>{name=>'平民', num=>0}}, lastWdsNum=>0, },
	5 => { roles=>{KILLER=>{name=>'杀手', num=>1}, PROBER=>{name=>'警察', num=>1}, SHEEP=>{name=>'平民', num=>3}}, lastWdsNum=>1, },
	6 => { roles=>{KILLER=>{name=>'杀手', num=>1}, PROBER=>{name=>'警察', num=>1}, SHEEP=>{name=>'平民', num=>4}}, lastWdsNum=>1, },
	7 => { roles=>{KILLER=>{name=>'杀手', num=>1}, PROBER=>{name=>'警察', num=>1}, SHEEP=>{name=>'平民', num=>5}}, lastWdsNum=>1, },
	8 => { roles=>{KILLER=>{name=>'杀手', num=>2}, PROBER=>{name=>'警察', num=>1}, SHEEP=>{name=>'平民', num=>5}}, lastWdsNum=>2, },
	9 => { roles=>{KILLER=>{name=>'杀手', num=>2}, PROBER=>{name=>'警察', num=>1}, SHEEP=>{name=>'平民', num=>6}}, lastWdsNum=>2, },
	10 => { roles=>{KILLER=>{name=>'杀手', num=>2}, PROBER=>{name=>'警察', num=>2}, SHEEP=>{name=>'平民', num=>6}}, lastWdsNum=>2, },
);
my %STAT=(alive=>'活的', dead=>'已死', lastWds=>'遗言中', argue=>'对辩中', '-'=>'未确认');
my $GOD = 'p0';
my %NS=($GOD=>{name=>'法官', role=>'GOD'});
my %context = (scence=>'init');
my %PS = ();
my %time_length=(signIn=>60*15, lastWds=>60*3, morning=>60*12, argue=>60*3, end=>60*5);
sub init0 {
	%PS = ();
	%context = ( scence=>'signIn', 
		signInEndTime=>'2016-02-25 22:53:00', lastWdsEndTime=>'2016-02-24 00:00:00', 
		morningEndTime=>'2016-02-24 00:00:00', argueEndTime=>'2016-01-08 23:14:00', 
		gameEndTime=>'2016-01-08 23:14:00',
		minUserNum=>6, maxUserNum=>10, lastWdsNum=>0, lastWdsEnd=>0, round=>0, argueNum=>0, 
		deadUserId=>'UNKOWN', checkUserId=>'UNKOWN', 
		responseMsg=>'');
	$context{signInEndTime} = getTime($time_length{signIn});
}

sub curTime { return strftime("%Y-%m-%d %H:%M:%S",localtime()); }
sub getTime { my $sec=shift(@_); return strftime("%Y-%m-%d %H:%M:%S",localtime(time()+$sec)); }
sub userNum { return scalar(keys %PS); }
sub chkInNum { my $num=0; for(values(%PS)) { $num++ if( exists($$_{stat}) && !($$_{stat}~~'') ); }; return $num; }
sub sheepNum { my $num=0; for(values(%PS)) { $num++ if ($$_{role}~~'SHEEP' && $$_{stat}~~['alive','argue']); }; return $num; }
sub proberNum { my $num=0; for(values(%PS)) { $num++ if ($$_{role}~~'PROBER' && $$_{stat}~~['alive','argue']); }; return $num; }
sub killerNum { my $num=0; for(values(%PS)) { $num++ if ($$_{role}~~'KILLER' && $$_{stat}~~['alive','argue']); }; return $num; }
sub unVotedNum { my $num=0; for(values(%PS)) { $num++ if ($$_{vote}~~'UNKOWN'); }; return $num; }
sub argueNum { my $num=0; for(values(%PS)) { $num++ if ($$_{stat}~~'argue'); }; return $num; }
sub deadNum { my $num=0; for(values(%PS)) { $num++ if ($$_{stat}~~'dead'); }; return $num; }

my $F_none = sub {
};
my $F_init = sub {
	my ($fromId, $cont, $fat) = @_;
	talk($GOD, 'ALL', $fat);
	init0(\%context, \%PS);
};
my $F_changeTime = sub {
	my ($fromId, $cont, $fat) = @_;
	if( $cont =~ /^(.*)=(.*)$/ ){
		my ($timer, $dlt) = ($1, $2);
		if(exists($context{$timer}) && $timer=~/EndTime$/) {
			$dlt = sprintf("%s-%s-%s %s:%s:%s", substr($dlt,0,4), substr($dlt,4,2), substr($dlt,6,2), substr($dlt,8,2), substr($dlt,10,2), substr($dlt,12,2));
			$context{$timer} = $dlt;
			reply($fromId, getMsg($fat, $timer, $dlt)); 
		}
	}
};
my $F_watchdog = sub {
	my ($fromId, $cont, $fat) = @_;
	# door-open
	return 0 if( $cont ~~ /^当前状态$/ ) ;
	return 0 if( $fromId ~~ [keys(%PS),$GOD] );
	return 0 if( $context{scence} eq 'signIn' && $cont ~~ /^地振高罡$/ ) ; 
	# door-closed
	if( $context{scence} eq 'signIn' ){
		reply($fromId, getMsg($fat->[0],$context{signInEndTime}));
	}else{
		reply($fromId, $fat->[1]);
	}
	return 1 ; 
};
my $F_addUser = sub {
	my ($fromId, $cont, $fat) = @_;
	reply($fromId, getMsg($fat->[0]));
	if( !exists($PS{$fromId}) ) {
        $PS{$fromId} = {name=>'', role=>'', stat=>''};
		reply($fromId, getMsg($fat->[1], $context{signInEndTime}));
	}
};

sub genUserListInfo {
	my $cnt = 0;
	my @arr = ();
	foreach my $id (sort keys %PS) {
		my $name = ( (exists($PS{$id}{name}) && $PS{$id}{name} ne '') ? $PS{$id}{name} : '-');
		my $role = ( (exists($PS{$id}{role}) && $PS{$id}{role} ne '') ? $PS{$id}{role} : '-');
		my $stat = ( (exists($PS{$id}{stat}) && $PS{$id}{stat} ne '') ? $PS{$id}{stat} : '-');
		my $vote = ( (exists($PS{$id}{vote}) && $PS{$id}{vote} ne '') ? $PS{$id}{vote} : '-');
		my $remark = ( (exists($PS{$id}{remark}) && $PS{$id}{remark} ne '') ? $PS{$id}{remark} : '-');
		$role = $USER_ROLES{userNum()}{roles}{$role}{name};
		$stat = $STAT{$stat};
		$remark =~ s/K([0-9]+)/第$1晚被杀/g; $remark =~ s/V([0-9]+)/第$1天被投/g;
		$vote = (($vote ~~ 'UNKOWN') ? "未投票" : "已投$PS{$vote}{name}") if( $vote ne '-' );
		$cnt++;

		$role = '-' unless( $context{scence} ~~ 'end' );
		$vote = '-' unless( $context{scence} ~~ ['vote','voteOut'] );
		push(@arr, join(",", "P$cnt", $name, $role, $stat, $vote, $remark));
	}
	return join(" | ", @arr);
}
my $F_listUser = sub {
	my ($fromId, $cont, $fat) = @_;
	reply($fromId, genUserListInfo());
};

my $F_listUserDetail = sub {
	my ($fromId, $cont, $fat) = @_;
	my $cnt = 0;
	my @arr = ();
	foreach my $id (sort keys %PS) {
		push(@arr, getMsg($fat, join(",", ++$cnt, $id, values($PS{$id}))));
	}
	reply($fromId, join(" | ", @arr));
};

my $F_assignUser = sub {
	my ($fromId, $cont, $fat) = @_;
	my $userNum = userNum ;
	my @roles = ();
	my @msg = ();
	foreach my $roleId (sort keys $USER_ROLES{$userNum}{roles}){
		my $roleInfo = $USER_ROLES{$userNum}{roles}{$roleId};
		push(@msg, "$roleInfo->{name}:$roleInfo->{num}");
		for(my $i=0; $i<$roleInfo->{num}; $i++) { push(@roles, $roleId); }
	}
	foreach my $userId (sort keys %PS) {
		talk($GOD, $userId, getMsg($fat->[0], $userNum, join(",", @msg)));
	}

	$context{lastWdsNum} = $USER_ROLES{$userNum}{lastWdsNum};
	my $n = $userNum;
	my @names = @NAME_LIST;
	foreach my $userId (sort keys %PS) {
		next unless $PS{$userId}{role} ~~ '';
		$PS{$userId}{role} = splice(@roles, int(rand($n)), 1);
		$PS{$userId}{name} = splice(@names, int(rand($n)), 1);
		$n--;
		talk($GOD, $userId, getMsg($fat->[1], $PS{$userId}{name}, $USER_ROLES{$userNum}{roles}{$PS{$userId}{role}}{name}));
	}
};
my $F_checkIn = sub {
	my ($fromId, $cont, $fat) = @_;
	$PS{$fromId}{stat} = 'alive';
	reply($fromId, getMsg($fat, $PS{$fromId}{name}));
};
my $F_darkIn = sub {
	my ($fromId, $cont, $fat) = @_;
	$context{round} ++;
	$context{argueNum} = 2;
	$context{checkUserId} = 'UNKOWN';
	$context{deadUserId}  = 'UNKOWN';
	talk($GOD, 'ALL', getMsg($fat->[0]));
	talk($GOD, 'UNI_K', getMsg($fat->[1]));
	talk($GOD, 'UNI_P', getMsg($fat->[2]));
};
my $F_killUser = sub {
	my ($fromId, $cont, $fat) = @_;

	my $deadId = 'UNKOWN';
	foreach my $id (sort keys %PS) {
		if( $PS{$id}{name} ~~ $cont ) { 
			if( $PS{$id}{stat} ~~ 'alive' ){ $deadId = $id; }
			else { $deadId = 'DEAD'; }
		}
	}
	given($deadId){
		when('UNKOWN') { reply($fromId, getMsg($fat->[0], $cont)); }
		when('DEAD')   { reply($fromId, getMsg($fat->[1], $cont)); }
		default {
			$context{deadUserId} = $deadId;
			talk($GOD, 'UNI_K', getMsg($fat->[2], $cont));
		}
	}
};
my $F_checkUser = sub {
	my ($fromId, $cont, $fat) = @_;
	if( !($context{checkUserId} ~~ 'UNKOWN') ) { reply($fromId, getMsg($fat->[0], $cont)); return; }

	my $checkId = 'UNKOWN';
	foreach my $id (sort keys %PS) {
		if( $PS{$id}{name} ~~ $cont ) {
			if( $PS{$id}{stat} ~~ 'alive' ) { $checkId = $id; }
			else { $checkId = 'DEAD'; }
		}
	}
	given($checkId){
		when('UNKOWN') { reply($fromId, getMsg($fat->[1], $cont)); }
		when('DEAD')   { reply($fromId, getMsg($fat->[2], $cont)); }
		default {
			$context{checkUserId} = $checkId;
			talk($GOD, 'UNI_P', getMsg((($PS{$checkId}{role} ~~ 'KILLER')?$fat->[3]:$fat->[4]), $PS{$checkId}{name}));
		}
	}
};
my $F_darkEnd = sub {
	my ($fromId, $cont, $fat) = @_;
	$PS{$context{deadUserId}}{stat} = 'dead';
	$PS{$context{deadUserId}}{remark} = "K$context{round}";
	talk($GOD, 'ALL', getMsg($fat, $PS{$context{deadUserId}}{name}));
};
my $F_lastWdsIn = sub {
	my ($fromId, $cont, $fat) = @_;
	$context{lastWdsEnd} = 0;
	$context{lastWdsEndTime} = getTime($time_length{lastWds});
	$PS{$context{deadUserId}}{stat} = 'lastWds';
	talk($GOD, 'ALL', getMsg($fat, $PS{$context{deadUserId}}{name}, $context{lastWdsEndTime}));
};
my $F_lastWdsEnd = sub {
	my ($fromId, $cont, $fat) = @_;
	$context{lastWdsNum}--;
	$context{lastWdsEnd} = 1;
	$PS{$context{deadUserId}}{stat} = 'dead';
	talk($GOD, 'ALL', getMsg($fat->[0], $PS{$context{deadUserId}}{name}));
};
my $F_morning = sub {
	my ($fromId, $cont, $fat) = @_;
	if($context{lastWdsEnd} == 0){
		$context{lastWdsNum}--;
		$context{lastWdsEnd} = 1;
		$PS{$context{deadUserId}}{stat} = 'dead';
		talk($GOD, 'ALL', getMsg($fat->[0], $PS{$context{deadUserId}}{name}));
	}
	$context{morningEndTime} = getTime($time_length{morning});
	talk($GOD, 'ALL', getMsg($fat->[1], $context{morningEndTime}));
};
my $F_voteIn = sub {
	my ($fromId, $cont, $fat) = @_;
	$context{voteMap} = 0;
	foreach my $id (sort keys %PS) {
		$PS{$id}{stat} = 'alive' if( $PS{$id}{stat} ~~ 'argue' );
		$PS{$id}{vote} = 'UNKOWN' if( $PS{$id}{stat} ~~ 'alive' );
	}
	talk($GOD, 'ALL', $fat);
};
my $F_vote = sub {
	my ($fromId, $cont, $fat) = @_;
	
	my $votedId = 'UNKOWN';
	foreach my $id (sort keys %PS) {
		if( $PS{$id}{name} ~~ $cont ) { 
			if( $PS{$id}{stat} ~~ 'alive'){ $votedId = $id; }
			else { $votedId = 'DEAD'; }
		}
	}
	given( $votedId ) {
		when ('UNKOWN') { reply($fromId, getMsg($fat->[0], $cont)); return; }
		when ('DEAD') { reply($fromId, getMsg($fat->[1], $cont)); return; }
		default {
			$PS{$fromId}{vote} = $votedId;
			reply($fromId, getMsg($fat->[2], $cont)); 
		}
	}
};
my $F_voteOut = sub {
	my ($fromId, $cont, $fat) = @_;
	my %votedMap = ();
	foreach my $id (keys %PS) {
		push(@{$votedMap{$PS{$id}{vote}}}, $PS{$id}{name}) if ($PS{$id}{stat} ~~ 'alive') ;
	}

	my @voteResultStr = ($fat->[0]);
	foreach my $votedId (keys %votedMap) {
		push(@voteResultStr, getMsg($fat->[1], $PS{$votedId}{name}, join(',', @{$votedMap{$votedId}}))); 
	}
	talk($GOD, 'ALL', join(' | ', @voteResultStr));

	my @maxArr = (); 
	foreach my $votedId (keys %votedMap) {
		if (@maxArr <= 0 || @{$votedMap{$votedId}} == @{$votedMap{$maxArr[0]}}) {
			push(@maxArr, $votedId);
		} elsif ( @{$votedMap{$votedId}} > @{$votedMap{$maxArr[0]}} ) {
			@maxArr = ($votedId);
		}
	}
	if(@maxArr == 1) {
		my $id = shift @maxArr;
		$PS{$id}{stat} = 'dead';
		$PS{$id}{remark} = "V$context{round}";
		talk($GOD, 'ALL', getMsg($fat->[2], $PS{$id}{name}));
	} else {
		if($context{argueNum} > 0){
			foreach my $id (@maxArr) { $PS{$id}{stat} = 'argue'; }
		}
	}

	foreach my $id (sort keys %PS) { $PS{$id}{vote} = ''; }
};
my $F_argueIn = sub {
	my ($fromId, $cont, $fat) = @_;
	$context{argueNum} -- ;

	my @nameList = ();
	foreach my $id (keys %PS) { push(@nameList, $PS{$id}{name}) if($PS{$id}{stat} ~~ 'argue'); }
	$context{argueEndTime} = getTime($time_length{argue});
	talk($GOD, 'ALL', getMsg($fat, join(',', @nameList), $context{argueEndTime}));
};
my $F_gameOver = sub {
	my ($fromId, $cont, $fat) = @_;
	$context{gameEndTime} = getTime($time_length{end});
	my @arr = ();
	if(killerNum() > 0){
		push(@arr, getMsg($fat->[0]));
	} else {
		push(@arr, getMsg($fat->[1]));
	}
	push(@arr, $fat->[3]);
	push(@arr, getMsg($fat->[2], genUserListInfo()));
	push(@arr, $fat->[3]);
	talk($GOD,'ALL', join(" | ", @arr));
};
my $F_cleanUp = sub {
	my ($fromId, $cont, $fat) = @_;
	talk($GOD, 'ALL', $fat);
};

my %scence=(
	init	=>{name=>'创建中',	enterEvent=>'NONE',		talkTo=>['ANONY'],		direct=>['NONE'],			next=>[{signIn=>['TRUE']}],	},
	signIn	=>{name=>'报名中',	enterEvent=>'INIT',		talkTo=>['ANONY'],		direct=>['SIGNIN'],	next=>[{checkIn=>['SIGNIN_TIMER','MAXUSER']}],	},
	checkIn	=>{name=>'报名结束等待确认',	enterEvent=>'ASSIGN',	talkTo=>['ALL','UNCHK'],		direct=>['CHKIN'],	next=>[{dark=>['ALL_CHKIN']}],		},
	dark	=>{name=>'天黑了',	enterEvent=>'DARKIN',	talkTo=>['UNI_K','UNI_P'],	direct=>['KILL','PROBE'],	next=>[{'darkEnd'=>['DARK_END']}],	 },
	darkEnd	=>{name=>'天快亮',	enterEvent=>'DARK_END',	talkTo=>['MUTE'],		direct=>[''],		next=>[{end=>['KILLER_WIN','KILLER_FAIL']},{lastWds=>['LASTWDS']},{morning=>['NO_LASTWDS']}], 	},
	lastWds	=>{name=>'遗言中',	enterEvent=>'LW_IN',		talkTo=>['LAST'],		direct=>['LW_END'],	next=>[{morning=>['LW_END']}],		},
	morning	=>{name=>'天亮了',	enterEvent=>'MORNING',	talkTo=>['ALL'],		direct=>[''],		next=>[{vote=>['MORNING_TIMER']}],	},
	vote	=>{name=>'投票中',	enterEvent=>'VOTE_IN',	talkTo=>['MUTE'],		direct=>['VOTE'],	next=>[{voteOut=>['VOTE_OUT']}],	},
	voteOut	=>{name=>'数票中',	enterEvent=>'VOTE_OUT',	talkTo=>['MUTE'],		direct=>[''],		next=>[{end=>['KILLER_WIN','KILLER_FAIL']},{argue=>['VOTE_ARGUE']},{dark=>['KILLER_SURVIVE']}],	},
	argue	=>{name=>'对辩中',	enterEvent=>'ARGUE',		talkTo=>['ARGUE'],		direct=>[''],		next=>[{vote=>['ARGUE_TIMER']}],	},
	end		=>{name=>'已结束',	enterEvent=>'END',		talkTo=>['FINAL'],		direct=>['CLEANUP'],next=>[{signIn=>['GAME_QUIT']}],	}
);
my $F_showGSstat = sub {
	my ($fromId, $cont, $fat) = @_;
	
	reply($fromId, getMsg($fat->[0], userNum(), deadNum(), $scence{$context{scence}}{name}));
	if(!($fromId ~~ [keys %PS]) && !($context{scence} ~~ 'signIn')){
		reply($fromId, $fat->[1]);
		return;
	}
	given($context{scence}){
		when(!($fromId ~~ [keys %PS])){ reply($fromId, getMsg($fat->[2], $context{signInEndTime}, $context{minUserNum}, $context{maxUserNum})); }
		when('signIn'){ reply($fromId, getMsg($fat->[3], $context{signInEndTime}, $context{minUserNum}, $context{maxUserNum})); }
		when('checkIn'){ reply($fromId, getMsg($fat->[4], userNum()-chkInNum())); }
		when('dark'){ reply($fromId, ($context{deadUserId} ne 'UNKOWN')?$fat->[5]:$fat->[6]); }
		when('vote'){ reply($fromId, getMsg($fat->[7], unVotedNum())); }
	}
};

my %direction=(
	NONE	=>{cmd=>'NONE', func=>$F_none, },
	INIT	=>{cmd=>'INIT',	role=>'GOD', stat=>'',	func=>$F_init, fat=>'新游戏已开局，喊口令开始报名', },
	TIMER	=>{cmd=>'TIMER (.*=.*)',	role=>'', stat=>'',	func=>$F_changeTime, fat=>'$1已改为$2',},
	WATCHDOG=>{cmd=>'门卫', func=>$F_watchdog, fat=>['游戏报名中,回复\'当前状态\'可看更多情况','报名已结束,请等待下次报名. 回复\'当前状态\'可看更多情况']},
	STATUS	=>{cmd=>'当前状态',	func=>$F_showGSstat,	fat=>['当前游戏:黄草梁杀人夜,现有$1人($2已死),状态:$3','报名已结束, 请等待下次报名','回复\'地振高罡\'可报名(人数下限$2, 上限$3)。截止时间$1','你已报名进入, 未分配角色, 请等待报名截止时间$1(人数下限$2, 上限$3)','还有$1人未确认','警察还未验人','杀手还未杀人','还有$1人未投票'],},
	ULIST	=>{cmd=>'用户列表',	role=>'',		stat=>'',	func=>$F_listUser,	fat=>'$1',	},
	DLIST	=>{cmd=>'人员详细',	role=>'',		stat=>'',	func=>$F_listUserDetail,	fat=>'$1',			},
	SIGNIN	=>{cmd=>'地振高罡',								func=>$F_addUser,	fat=>['门朝大海','黄草梁露营报名成功。请耐心等待其他人报名, 报名截止时间$1'], 		},
	ASSIGN	=>{cmd=>'点名签到',	role=>'GOD',	stat=>'',	func=>$F_assignUser, fat=>['报名结束, 即将天黑。目前总人数$1($2), 回复\'用户列表\'随时查看所有人物','你的代号:$1, 角色:$2。请回复\'确认\',然后等待天黑'],	},
	CHKIN	=>{cmd=>'确认',		role=>'',		stat=>'',	func=>$F_checkIn,fat=>'$1已确认',},
	DARKIN	=>{cmd=>'天黑了',	role=>'GOD',	stat=>'',	func=>$F_darkIn,		fat=>['天黑请闭眼, 群聊关闭','杀手对讲已开(杀人指令: \'杀：XX\')','警察对讲已开(验人指令: \'验：XX\')'],},
	KILL	=>{cmd=>'杀[:|：\s]+(.+)',	role=>'KILLER',	stat=>'alive',	func=>$F_killUser,	fat=>['非游戏人名: \'$1\'','$1已死, 不可再杀','已收到指令: 杀$1'],		},
	PROBE	=>{cmd=>'验[:|：\s]+(.+)',	role=>'PROBER',	stat=>'alive',	func=>$F_checkUser,	fat=>['验人已结束, 警察请闭眼','非游戏人名: \'$1\'','$1已死, 不能再验','验人结果: $1是杀手','验人结果: $1不是杀手'],		},
	DARK_END=>{cmd=>'天黑结束',	role=>'GOD',	stat=>'',	func=>$F_darkEnd,	fat=>'$1已死。杀手和警察请禁言, 马上天亮',		},
	LW_IN	=>{cmd=>'留遗言',	role=>'GOD',	stat=>'',	func=>$F_lastWdsIn,	fat=>'请$1留遗言,结束时间$2',		},
	LW_END	=>{cmd=>'遗言结束',	role=>'',stat=>'lastWds',	 func=>$F_lastWdsEnd,	fat=>['$1遗言结束'],	},
	MORNING	=>{cmd=>'天亮了',	role=>'GOD',	stat=>'',	func=>$F_morning,	fat=>['$1遗言结束','天亮了。群聊开放, 投票时间$1'],	},
	VOTE_IN	=>{cmd=>'投票开始',	role=>'GOD',	stat=>'',	func=>$F_voteIn,		fat=>'开始投票, 群聊关闭 | 投票指令: \'投：XX\'',	},
	VOTE	=>{cmd=>'投[:|：\s]+(.+)',	role=>'',		stat=>'alive',	func=>$F_vote,		fat=>['非游戏人名: \'$1\'','$1已死, 投票无效','收到投票: $1'],	},
	VOTE_OUT=>{cmd=>'投票结束',	role=>'GOD',	stat=>'',	func=>$F_voteOut,		fat=>['投票结果:','投$1的: $2','$1已被投死'],	},
	ARGUE	=>{cmd=>'对辩开始',	role=>'GOD',	stat=>'',	func=>$F_argueIn,	fat=>'请$1进行对辩, 群聊已关闭。再次投票时间$2',	},
	END		=>{cmd=>'游戏结束',	role=>'GOD',	stat=>'',	func=>$F_gameOver,	fat=>['游戏结束, 杀手胜利。群聊开放','游戏结束, 警民胜利。群聊开放','$1','************'],	},
	CLEANUP	=>{cmd=>'游戏归零',	role=>'GOD',	stat=>'',	func=>$F_cleanUp,	fat=>'游戏关闭, 玩家退出。',	},
);
my %condition=(
	TRUE			=>sub { return 0 < 1 },
	SIGNIN_TIMER	=>sub { return curTime gt $context{signInEndTime} && userNum() >= $context{minUserNum}; },
	MAXUSER			=>sub { return userNum() >= $context{maxUserNum}; },
	ALL_CHKIN		=>sub { return chkInNum() >= userNum(); },
	DARK_END		=>sub { return $context{deadUserId} ne 'UNKOWN' && $context{checkUserId} ne 'UNKOWN';},
	LASTWDS			=>sub { return $context{lastWdsNum} >  0; },
	NO_LASTWDS		=>sub { return $context{lastWdsNum} <= 0; },
	LW_END			=>sub { return curTime gt $context{lastWdsEndTime} || $context{lastWdsEnd} == 1; },
	KILLER_WIN		=>sub { return ( proberNum() <= 0 || sheepNum() <= 0 ); },
	KILLER_FAIL		=>sub { return killerNum() <= 0; },
	KILLER_SURVIVE	=>sub { return argueNum () < 1 },
	VOTE_ARGUE		=>sub { return argueNum () > 1 },
	VOTE_OUT		=>sub { return unVotedNum() <= 0; },
	MORNING_TIMER	=>sub { return curTime gt $context{morningEndTime}; },
	ARGUE_TIMER		=>sub { return curTime gt $context{argueEndTime}; },
	GAME_QUIT		=>sub { return curTime gt $context{gameEndTime};},
);
my %channel=(
	MUTE	=>{fat=>'[法官]: 不许说话 (当前:$1, 角色:$2, 状态:$3)',	echo=>1,	role=>'',		stat=>''},
	ANONY	=>{fat=>'[匿名]: $1',		echo=>0,	role=>'',		stat=>''},
	UNCHK	=>{fat=>'[$1(未确认)]: $2',	echo=>0,	role=>'',		stat=>''},
	ALL		=>{fat=>'[$1]: $2',			echo=>0,	role=>'',		stat=>'alive'},
	UNI_K	=>{fat=>['[杀手对讲|$1]: $2','无人接收消息(就你一个杀手，就别对讲了)'],	echo=>0,	role=>'KILLER',	stat=>'alive'},
	UNI_P	=>{fat=>['[警察对讲|$1]: $2','无人接收消息(就你一个警察，就别对讲了)'],	echo=>0,	role=>'PROBER',	stat=>'alive'},
	LAST	=>{fat=>'[遗言广播|$1]: $2',	echo=>0,	role=>'',		stat=>'lastWds'},
	ARGUE	=>{fat=>'[对辩广播|$1]: $2',	echo=>0,	role=>'',		stat=>'argue'},
	DEAD	=>{fat=>['[墓地联通|$1]: $2','无人接收消息(孤独的人最可悲,是不是/:,@P 别急,等会儿就有人下来陪你了)'],	echo=>0,	role=>'',		stat=>'dead'},
	FINAL	=>{fat=>'[$1]:$2',			echo=>0,	role=>'',		stat=>''},
);

sub reply {
	my ($to, $msg) = @_;
	return if($to ~~ $GOD);
#	say join("\t", @_);
	$context{responseMsg} .= join("\t", @_)."\n";
} 
sub getMsg {
	my $msg = $_[0];
	for(my $i=1; $i<@_; $i++){  $msg =~ s/\$$i/$_[$i]/g; }
	return $msg;
}
sub checkAuthority {
#ps\dir		r-s-	r空s空	r空s值	r值s空	r值s值
#r-s-		1		0		0		0		0
#r空s空		1		1		0		0		0
#r值s值		1		1		*		*		*
	my ($fromId, $role, $stat) = @_;
	return 1 if( $fromId ~~ $GOD || (exists($PS{$fromId}) && $PS{$fromId}{role} ~~ 'GOD'));
	return 1 if( !defined($role) && !defined($stat) );
	return 0 if( !exists($PS{$fromId}) || (!exists($PS{$fromId}{role}) && !exists($PS{$fromId}{stat})) );
	return 1 if( $role ~~ '' && $stat ~~ '' );
	return 0 if( $PS{$fromId}{role} ~~ '' && $PS{$fromId}{stat} ~~ '' );
	return ( $PS{$fromId}{stat} ~~ $stat ) if ( $role ~~ '' );
	return ( $PS{$fromId}{role} ~~ $role ) if ( $stat ~~ '' );
	return ( $PS{$fromId}{role} ~~ $role && $PS{$fromId}{stat} ~~ $stat );
}
sub getDirection {
	my ($direction) = @_;
	return sub {
		my ($fromId, $cont) = @_;
		if( exists($direction->{func}) && $cont =~ /^$direction->{cmd}$/ ) {
			$cont = $1 if defined($1) ;
			return 1 unless checkAuthority($fromId, $direction->{role}, $direction->{stat}); 
			$direction->{func}->($fromId, $cont, $direction->{fat});
			return 0;
		}
		return -1;
	}
}
sub talk {
	my ($fromId, $to, $msg) = @_;
	return 0 if ( $to ~~ [keys %channel] && !checkAuthority($fromId, $channel{$to}{role}, $channel{$to}{stat}) );
	my $fromUserName = (($fromId ~~ $GOD) ? $NS{$GOD}{name} : $PS{$fromId}{name});
	given($to) {
		when( /ALL/ || /UNCHK/ || /LAST/ || /ARGUE/ || /FINAL/ ) {
			foreach my $userId (sort keys %PS) {
				talk($fromId, $userId, getMsg($channel{$to}{fat}, $fromUserName, $msg));
			}
		}
		when( 'ANONY' ) {
			foreach my $userId (sort keys %PS) {
				talk($fromId, $userId, getMsg($channel{$to}{fat}, $msg));
			}
		}
		when( /UNI_K/ || /UNI_P/ ) {
			my $hasSend = 0;
			foreach my $userId (sort keys %PS) {
				$hasSend += talk($fromId, $userId, getMsg($channel{$to}{fat}->[0], $fromUserName, $msg)) if($PS{$userId}{role} ~~ $channel{$to}{role});
			}
			reply($fromId, $channel{$to}{fat}->[1]) if( $hasSend <= 1 && $fromId ne $GOD);
		}
		when( 'DEAD' ) {
			my $hasSend = 0;
			foreach my $userId (sort keys %PS) {
				$hasSend += talk($fromId, $userId, getMsg($channel{$to}{fat}->[0], $fromUserName, $msg)) if($PS{$userId}{stat} ~~ $channel{$to}{stat});
			}
			reply($fromId, $channel{$to}{fat}->[1]) if( $hasSend <= 1 && $fromId ne $GOD);
		}
		when( 'MUTE' ) { reply($fromId, getMsg($channel{$to}{fat}, $scence{$context{scence}}{name}, $USER_ROLES{userNum()}{roles}{$PS{$fromId}{role}}{name}, $STAT{$PS{$fromId}{stat}})); }
		default { reply($to, $msg); }
	}
	return 1;
}
sub dealMsg {
	my ($fromId, $cont) = split('\t', shift(@_));
	$context{responseMsg} = '';

	# watchdog
	return $context{responseMsg} if( $direction{WATCHDOG}{func}->($fromId, $cont, $direction{WATCHDOG}{fat}) );

	my $rc_cmd = -9;
	foreach my $d ('NONE', @{$scence{$context{scence}}{direct}}, 'STATUS', 'ULIST', 'DLIST', 'TIMER') {
		$rc_cmd = getDirection($direction{$d})->($fromId, $cont);
		last if( $rc_cmd >= 0 );
	}
	if( $rc_cmd == 0 ) {
		my $next = 0;
		foreach my $scence_map (@{$scence{$context{scence}}{next}}){
			foreach my $scence (keys $scence_map) {
				foreach my $c (@{$scence_map->{$scence}}) {
#					say "COND=$c";
					if( $condition{$c}->() ) {
						$context{scence} = $scence;
						$next = 1; last;
					}
				}
				last if $next;
			}
			last if $next;
		}
		if( $next ) {
			my $event = $direction{$scence{$context{scence}}{enterEvent}};
			getDirection($event)->($GOD, $$event{cmd});
		}
	}
	if( $rc_cmd < 0 ){
		foreach my $channelId (@{$scence{$context{scence}}{talkTo}}, 'DEAD', 'MUTE') {
#			say "channelId=$channelId";
			last if talk($fromId, $channelId, $cont);
		}
	}
	return $context{responseMsg};
}

#while(<STDIN>){
#	chomp;
#	say dealMsg($_);
#}

use constant MSG_SIZE => 4096;
my $local_port = 20300;
my $socket_listen=IO::Socket::INET->new(
		LocalPort=>$local_port,
		Type=>SOCK_STREAM,
		Proto=>"tcp",
		Reuse=>1,
		Listen=>8)
	or die "[Error] Failed to listen on port $local_port \n";
print "[Info] This tcp server is listening on port $local_port \n";
while(1){
	say "wait for accept ...";
	my $conn = $socket_listen->accept;
	say "accept from ".$conn->peerhost().":".$conn->peerport()." ...";
	handle_session($conn);
	say "close for ".$conn->peerhost().":".$conn->peerport()." .";
	close $conn;
}

sub handle_session {
	my $tom = shift;

	my $select = IO::Select->new();
	$select->add($tom);
	while(1) {
		my $tom_msg='';
		my $jim_msg='';

		my @readable = $select->can_read;
		foreach my $readable (@readable) {
			my $msg;
			my $bytes=$readable->sysread($msg, MSG_SIZE);
			goto EXIT if($bytes==0);
			if($readable eq $tom) {
				$tom_msg.=$msg;
			}
		}
		# ---- process start ---- #
		chomp($tom_msg);
		$tom_msg = decode("utf8", $tom_msg);
		$jim_msg = dealMsg($tom_msg);
		$jim_msg = encode("utf8", $jim_msg);
		# ---- process end   ---- #
		my @writable = $select->can_write;
		foreach my $writable (@writable) {
			if($writable eq $tom) {
				$writable->send($jim_msg);
			}
		}
	} # while(1);
EXIT:
	print "goto Exit","\n";
# end
}
