# git-multi-branch-executer

あるリポジトリの複数のブランチ(commit,tag)を指定して，コマンドを実行する

## for what?
* ブランチごとにビルドを実行し，それらのベンチマークを比較するため

## how to run
```
git-multi-branch-exec.sh -y git-multi-branch-exec.yml new
```

## specification
* `~/.cache/git-multi-branch-executer/`以下に現在のworking directoryのgitのrepositoryを`cp`する
  * 共通で利用するファイル
    * e.g. exec cmd file, patch file etc...
    * untracked filesもしくは，指定するブランチでアクセス可能でなければならない
    * ブランチで分割するほどではない差分は，patch fileを利用すると良い
* 実行
  * 並列数を指定して実行する(logのみやすさの観点を考えること)
    * 設定の`yml`を分割して実行すれば，そのスコープでの並列処理は可能
  * 基本的に，指定した順番に実行するが，並列数によって，前後する可能性がある
  * それぞれの実行はno dependencyであると仮定する
* log
  * main branchに全体の実行ログの結果を格納するディレクトリや設定ファイルを配置する?
  * 命名規則
    * WIP
* コピー先のworking directoryはgit内に存在する設定ファイル(yml)のdirectory
* ymlの設定ファイルの書き方はexampleを参照
  * 特に，省略する場合の記述に注意
  * patchesやscritpsにおいて，tabを利用しないこと(yqのparseでtsv形式を利用しているため)

## 実装内容
* 現在のブランチをまるごとtmp directoryにコピーすることを繰り返す
  * git-work-tree機能を利用して，コピー側ではread-onlyとする? untrackedファイルをコマンドでコピーすれば同じことが可能では?
  * そもそも，同一ブランチは無理なので，自動追従は無理じゃない...?
