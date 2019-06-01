# git-multi-branch-executer

あるリポジトリの複数のブランチ(commit,tag)を指定して，コマンドを実行する

## for what?
* ブランチごとにビルドを実行し，それらのベンチマークを比較するため

## specification
* tmp directoryにまるごとコピーするが，cache directoryを利用する
  * WARN: 初回はgitでuntracked filesもコピーするが，以降はコピーされない
  * 共通で利用するファイル
    * e.g. exec cmd file, patch file etc...
    * untracked filesもしくは，指定するブランチでアクセス可能でなければならない
    * ブランチで分割するほどではない差分は，patch fileを利用すると良い
* 実行
  * 並列数を指定して実行する
  * 基本的に，指定した順番に実行するが，並列数によって，前後する可能性がある
  * それぞれの実行はno dependencyであると仮定する
* log
  * main branchに全体の実行ログの結果を格納するディレクトリや設定ファイルを配置する
    * tmp directoryの名前
  * 命名規則
    * WIP
* コピー先のworking directoryはgit内に存在する設定ファイル(yml)のdirectory
* ymlの設定ファイルの書き方はexampleを参照
  * 特に，省略する場合の記述に注意

## 実装内容
* 現在のブランチをまるごとtmp directoryにコピーすることを繰り返す
  * git-work-tree機能を利用して，コピー側ではread-onlyとする? untrackedファイルをコマンドでコピーすれば同じことが可能では?
  * そもそも，同一ブランチは無理なので，自動追従は無理じゃない...?
* そこから，指定したブランチにcheckoutを行う
* branchの指定と何かしらの引数の指定を同時に行う?
  * master:OPT_O3.patch,a.patch,b.sh:名前を記述可能として，省略時には ここはymlが良いのでは?
    * patchは勝手に適用
    * shは勝手に実行
    * :や,は特殊扱い
* multi-branch-pre_hook.sh
* multi-branch-exec.shを実行する
  * 各ブランチでの条件分けは?
  * multi-branch-pre_hook.sh
  * ブランチの指定と，利用するファイル or コマンドの指定を単純なルールでやりたい???
    * python yml?(柔軟性はなくなるが，管理しやすい?)
    * shell script? (単純な記述でOKなら，一番柔軟)
* multi-branch-post_hook.sh
