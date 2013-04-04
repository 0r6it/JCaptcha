package JCaptcha; # クラスのパッケージ名を宣言
############################################################
# タイトル：かんたん日本語画像認証（アルファベットも可）
# 動作環境：UNIX系OS （Windowsでは正常に動作しません）
# 作者：ORBIT
# 開発者ブログ：http://www.orsx.net/blog/
############################################################

use strict;
use warnings;

use Image::Magick;

sub new{
	# 引数を受ける
	my ( $class, @args ) = @_;
	my %args = ref $args[0] eq 'HASH' ? %{ $args[0] } : @args;
	my $self = { %args }; #クラスプロパティ

	#++++++++++++++++++++#
	# デフォルト値を指定 #
	#++++++++++++++++++++#
	# 暗号化鍵
	$self->{ Key }    = 'MD'                    unless defined $self->{ Key };
	# 言語(JP/ENG)
	$self->{ Lang }   = 'JP'                    unless defined $self->{ Lang };
	# 背景画像
	$self->{ Back }   = './background.jpg'      unless defined $self->{ Back };
	# フォント
	$self->{ Font }   = './sazanami-gothic.ttf' unless defined $self->{ Font };
	# 文字のサイズ
	$self->{ Size }   = '35'                    unless defined $self->{ Size };
	# 文字の色
	$self->{ Color }  = 'red'                   unless defined $self->{ Color };
	# 文字の長さ
	$self->{ Length } = '5'                     unless defined $self->{ Length };
	# 有効期限(1日÷4で0.25＝6時間)
	$self->{ Limit }  = '0.25'                  unless defined $self->{ Limit };
	# 認証画像の保存場所
	$self->{ Imgdir } = './tmp/imgs/'           unless defined $self->{ Imgdir };
	# 暗号
	$self->{ Code }   = 'NULL'                  unless defined $self->{ Code };

	#print "NEW: $self->{ Code } , $self->{ Key }\n"; # デバッグ
	# 返り値
	return bless $self , $class;
}

#暗号化
sub md5 {
	my $self = shift; #クラスプロパティ

	#print "MD51: $self->{ Code } , $self->{ Key }\n"; # デバッグ
	# 入力されたデータを暗号化(MD5) Windowsではcrypt関数の仕様上正常に動きません
	$self->{ Code } = crypt ($self->{ Code },'$1$'.$self->{ Key });
	$self->{ Code } =~ /.*\$1\$$self->{ Key }\$(.*).*/;
	$self->{ Code } = $1;
	$self->{ Code } =~ s/\.|\//-/g; # 使えない文字を置換

	#print "MD52: $self->{ Code } , $self->{ Key }\n"; # デバッグ
	return $self->{ Code };
}

#画像認証用画像作成
sub makeimgcode{
	my $self = shift; # クラスプロパティ

	#print "MAK1: $self->{ Code } , $self->{ Key }\n"; # デバッグ
	# 有効期限を過ぎた画像ファイルを削除
	opendir(DIR,$self->{ Imgdir });
	my @list = readdir(DIR);
	foreach my $file (@list) {
		next if -d $file;
		unlink "$self->{ Imgdir }$file" if (-M "$self->{ Imgdir }$file" > $self->{ Limit });
	}
	close(DIR);

	my @character;
	if($self->{ Lang } eq "JP"){
		# 中国BOT・韓国BOT避け(和製漢字+仮名)
		@character = ('匂','笹','働','峠','枠','俣','畑','搾','込','腺','辻','栃','凧','あ','い','う','え','お');
	}else{
		# 普通BOT避けに利用する場合のランダムな英数を作成する
		@character = ('0'..'9','a'..'z');        # 英数版
	}
	my $pcode;
	for ( my $i = 1; $i <= $self->{ Length } ; $i++ ){
		$pcode .= $character[rand(@character)]; 
	}

	my $imgcode = $pcode;

	# ファイル名暗号化(MD5)
	$self->{ Code } = $pcode;
	$self->{ Code } = $self->md5(); # 暗号化
	$self->{ Code } = "$self->{ Imgdir }$self->{ Code }\.jpg";

	# 画像作成
	my $img = Image::Magick->new;
	$img->Read($self->{ Back });
	$img->Annotate(text=>$imgcode,
		geometry=>'+0+0',
		gravity=>'Center',
		fill=>$self->{ Color },
		font=>$self->{ Font },
		pointsize=>$self->{ Size });
	$img->Write($self->{ Code });
	undef $img;

	#print "MAK2: $self->{ Code } , $self->{ Key }\n"; # デバッグ
	return $self->{ Code };
}

#画像認証検証
sub enimgcode{
	my $self = shift; # クラスプロパティ

	$self->{ Code } = $_[0] if( @_ ); # アクセッサを定義して入力された画像の文字を受取る

	#print "ENI1: $self->{ Code } , $self->{ Key }\n"; # デバッグ

	$self->{ Code } = $self->md5( Code => $self->{ Code } ); # 暗号化
	if (! -f "$self->{ Imgdir }$self->{ Code }\.jpg"){ # 画像ファイルが存在するかを確認
		return 0;
	}else{
		unlink "$self->{ Imgdir }$self->{ Code }\.jpg"; # 使用した画像を抹消
		return 1;
	}
	#print "ENI2: $self->{ Code } , $self->{ Key }\n"; # デバッグ
}

1;

__END__

==== ビックリするくらい簡単な利用法 ====

#!/usr/bin/perl

# 当モジュールを呼び出し
use JCaptcha;

# オブジェクトの生成
my $obj = JCaptcha->new(
		Key    => OR, # 鍵を指定
		Lang   => ENG,# 言語を指定(JP/ENG)
		Length => 10  # 文字の長さを指定
	);

# 認証画像作成用メソッドを呼び出す
my $tmp1 = $obj->makeimgcode(); # 認証用画像を作成し、その画像までのパスを受ける
print "$tmp1\n";

#==============================================#
# 画像を表示し、入力を行う処理を書いてください #
#==============================================#

# 認証
# 入力された文字列で認証を行い、正しければ"1"間違っていれば"0"を受ける（受け渡す文字列はフラグ無しUTF-8とする）
my $tmp2 = $obj->enimgcode('入力を受けた文字列');
print "$tmp2\n";
