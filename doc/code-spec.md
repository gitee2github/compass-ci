code注意事项
============

- 代码应当放进函数里 不要在脚本顶层直接写逻辑
- 代码应当放进lib/里 脚本本身最小化, 仅解析命令行参数, 调用lib/入口函数
- 如果出现了全局变量 一般意味着需要写一个 class/module 来放这个状态量了
- 一个函数, 不要超过10行代码
- 起准确和有意义的变量/函数名字, 名字要让人看出赋予他们的确切意义

重构友好编码
============

基本原则:
- 预防自己的代码造成他人的几大困难
  - 难以理解 不敢下手
  - 不知道怎么找到*所有*关联逻辑
  - 不知道自己不知道 (unknown unknown)
- 设想将来做重构, 或者需要理解任何一个高层次的功能/流程,
  一个新人应当可以通过 git grep 一两个关键字或者pattern,
  就能找到所有相关底层代码与文档, 而不必担心有所遗漏.

基本方法:
- 隐式场景显式化: 加注释明确代码的各类隐含目的, 意义, 场景, 数据示例等等
- 隐式依赖显式化: 定义相同的ID, 把所有的关联文档与各处代码串起来
- 分散依赖集中化: 定义类/函数/assert, 封装/强制 各类设计中的假设, 约定与规则

PATCH注意事项
=============

- PATCH title 应当简要说明做了什么 (what)
- PATCH changelog / code comment 应当解释读者无法从代码简单推断的
  - 背景
  - 目的
  - 效果
  - 设计选项和权衡
  - 实际例子
  - 改进数字
  - bug场景, 出错消息原文
- PATCH 应当加上作者签名 (Signed-off-by: Name <email>)
- PATCH 最好不超过100行, 一个PATCH只做一件事, 避免混杂多个逻辑变更

PATCH参考材料
=============

The patch subject and changelog should be well written according to suggestions
here:

	https://github.com/thoughtbot/dotfiles/blob/master/gitmessage
	https://www.cnblogs.com/cpselvis/p/6423874.html

	http://www.ozlabs.org/~akpm/stuff/tpp.txt
	2: Subject:
	3: Attribution
	4: Changelog

	https://www.kernel.org/doc/html/latest/translations/zh_CN/process/submitting-patches.html#cn-describe-changes
	2) 描述你的改动
	3) 拆分你的改动
	8）回复评审意见

文档与易用性
============

- 每个feature都应当有
  - 用户文档
  - 设计文档
  - 指示对应的代码在哪里(class/func); 或者如果有多处代码互相配合, 指示用什么关键字grep能把它们串起来看

- 每个有命令行参数的脚本, 都应当支持help output (-h|--help|参数不够时 显示帮助信息)
  - dependencies/assumptions
  - input parameters
  - input/output example