KuGouMusic API

本文档仅列出所有接口路径及调用用例，请勿直接复制用例中的参数值，需替换为实际数据。

登录

· 手机登录
    路径：/login/cellphone
    用例：/login/cellphone?mobile=13800000000&code=123456
· 用户名登录
    路径：/login
    用例：/login?username=yourname&password=yourpass
· 开放接口登录
    路径：/login/openplat
    用例：/login/openplat?code=微信code
· 二维码登录 - 生成key
    路径：/login/qr/key
    用例：/login/qr/key
· 二维码登录 - 生成二维码
    路径：/login/qr/create
    用例：/login/qr/create?key=xxx
· 二维码登录 - 检测扫码状态
    路径：/login/qr/check
    用例：/login/qr/check?key=xxx
· 微信登录 - 生成二维码
    路径：/login/wx/create
    用例：/login/wx/create
· 微信登录 - 检测状态
    路径：/login/wx/check
    用例：/login/wx/check?timestamp=1691256061923&uuid=xxx

用户

· 刷新登录
    路径：/login/token
    用例：/login/token?token=xxx&userid=xxx
· 发送验证码
    路径：/captcha/sent
    用例：/captcha/sent?mobile=13800000000
· 获取dfid
    路径：/register/dev
    用例：/register/dev
· 获取用户额外信息
    路径：/user/detail
    用例：/user/detail（需登录）
· 获取用户VIP信息
    路径：/user/vip/detail
    用例：/user/vip/detail
· 获取用户歌单
    路径：/user/playlist
    用例：/user/playlist?page=1&pagesize=30
· 获取用户关注歌手
    路径：/user/follow
    用例：/user/follow
· 获取关注歌手消息
    路径：/user/follow/message
    用例：/user/follow/message?id=123&pagesize=30
· 获取用户云盘
    路径：/user/cloud
    用例：/user/cloud?page=1&pagesize=30
· 获取用户云盘音乐URL
    路径：/user/cloud/url
    用例：/user/cloud/url?hash=音乐hash&album_id=专辑id&name=文件名&album_audio_id=音频id
· 获取用户收藏视频
    路径：/user/video/collect
    用例：/user/video/collect?page=1&pagesize=30
· 获取用户喜欢视频
    路径：/user/video/love
    用例：/user/video/love?pagesize=30
· 获取用户听歌历史排行
    路径：/user/listen
    用例：/user/listen?type=0
· 获取用户最近听歌历史
    路径：/user/history
    用例：/user/history?bp=上一次返回值
· 获取继续播放信息
    路径：/lastest/songs/listen
    用例：/lastest/songs/listen?pagesize=30

歌单操作

· 收藏/新建歌单
    路径：/playlist/add
    用例：/playlist/add?name=歌单名&list_create_userid=用户id&list_create_listid=列表id
· 取消收藏/删除歌单
    路径：/playlist/del
    用例：/playlist/del?listid=xxx
· 歌单添加歌曲
    路径：/playlist/tracks/add
    用例：/playlist/tracks/add?listid=1&data=歌曲名|歌曲hash|专辑id|mixsongid
· 歌单删除歌曲
    路径：/playlist/tracks/del
    用例：/playlist/tracks/del?listid=1&fileids=fileid1,fileid2

专辑

· 新碟上架
    路径：/top/album
    用例：/top/album?type=1&page=1&pagesize=30
· 专辑信息
    路径：/album
    用例：/album?album_id=123,456&fields=language,authors
· 专辑详情
    路径：/album/detail
    用例：/album/detail?id=10729818
· 专辑音乐列表
    路径：/album/songs
    用例：/album/songs?id=10729818&page=1&pagesize=30

音乐

· 获取音乐URL
    路径：/song/url
    用例：/song/url?hash=歌曲hash&quality=320
· 获取音乐URL（新版）
    路径：/song/url/new
    用例：/song/url/new?hash=歌曲hash
· 获取歌曲高潮部分
    路径：/song/climax
    用例：/song/climax?hash=歌曲hash

搜索

· 搜索
    路径：/search
    用例：/search?keywords=周杰伦&cookie=token=xxx;userid=xxx;dfid=xxx
· 默认搜索关键词
    路径：/search/default
    用例：/search/default
· 综合搜索
    路径：/search/complex
    用例：/search/complex?keywords=海阔天空
· 热搜列表
    路径：/search/hot
    用例：/search/hot
· 搜索建议
    路径：/search/suggest
    用例：/search/suggest?keywords=海阔天空
· 歌词搜索
    路径：/search/lyric
    用例：/search/lyric?keywords=关键词&hash=歌曲hash
· 获取歌词
    路径：/lyric
    用例：/lyric?id=歌词id&accesskey=xxx&fmt=lrc&decode=true

歌单

· 歌单分类
    路径：/playlist/tags
    用例：/playlist/tags
· 歌单
    路径：/top/playlist
    用例：/top/playlist?category_id=0
· 主题歌单
    路径：/theme/playlist
    用例：/theme/playlist
· 音效歌单
    路径：/playlist/effect
    用例：/playlist/effect?page=1&pagesize=30
· 获取歌单详情
    路径：/playlist/detail
    用例：/playlist/detail?ids=collection_3_1863870844_4_0
· 获取歌单所有歌曲
    路径：/playlist/track/all
    用例：/playlist/track/all?id=collection_3_1863870844_4_0
· 获取歌单所有歌曲（新版）
    路径：/playlist/track/all/new
    用例：/playlist/track/all/new?listid=xxx
· 相似歌单
    路径：/playlist/similar
    用例：/playlist/similar?ids=collection_1_1341266283_964007_0
· 获取主题歌单所有歌曲
    路径：/theme/playlist/track
    用例：/theme/playlist/track?theme_id=18

主题

· 获取主题音乐
    路径：/theme/music
    用例：/theme/music
· 获取主题音乐详情
    路径：/theme/music/detail
    用例：/theme/music/detail?id=1002

推荐

· 歌曲推荐
    路径：/top/card
    用例：/top/card?card_id=1
· 歌曲推荐（概念版）
    路径：/top/card/youth
    用例：/top/card/youth?card_id=3006&pagesize=30

图片

· 获取歌手和专辑图片
    路径：/images
    用例：/images?hash=歌曲hash1,歌曲hash2&album_id=,专辑id2
· 获取歌手图片
    路径：/images/audio
    用例：/images/audio?hash=歌曲hash

音频信息

· 获取音乐相关信息
    路径：/audio
    用例：/audio?hash=歌曲hash
· 获取更多音乐版本
    路径：/audio/related
    用例：/audio/related?album_audio_id=573120919&show_detail=0
· 获取音乐伴奏信息
    路径：/audio/accompany/matching
    用例：/audio/accompany/matching?fileName=文件名&mixId=637735200&hash=歌曲hash
· 获取音乐K歌数量
    路径：/audio/ktv/total
    用例：/audio/ktv/total?songId=43522508&singerName=歌手名&songHash=歌曲hash
· 获取音乐详情
    路径：/privilege/lite
    用例：/privilege/lite?hash=歌曲hash
· 获取音乐专辑/歌手信息
    路径：/krm/audio
    用例：/krm/audio?album_audio_id=32155307&fields=album_info,base

私人FM

· 私人FM
    路径：/personal/fm
    用例：/personal/fm?hash=xxx&songid=xxx&playtime=60&mode=normal

乐库/电台

· banner
    路径：/pc/diantai
    用例：/pc/diantai
· 乐库banner
    路径：/yueku/banner
    用例：/yueku/banner
· 乐库电台
    路径：/yueku/fm
    用例：/yueku/fm
· 乐库
    路径：/yueku
    用例：/yueku
· 电台
    路径：/fm/class
    用例：/fm/class
· 电台-推荐
    路径：/fm/recommend
    用例：/fm/recommend
· 电台-图片
    路径：/fm/image
    用例：/fm/image?fmid=693,37
· 电台-音乐列表
    路径：/fm/songs
    用例：/fm/songs?fmid=693,37&fmtype=2,2&fmoffset=,5&fmsize=5,3

编辑精选

· 编辑精选
    路径：/top/ip
    用例：/top/ip
· 编辑精选数据
    路径：/ip
    用例：/ip?id=87473&type=author_list
· 编辑精选歌单
    路径：/ip/playlist
    用例：/ip/playlist?id=87473
· 编辑精选专区
    路径：/ip/zone
    用例：/ip/zone
· 编辑精选专区详情
    路径：/ip/zone/home
    用例：/ip/zone/home?id=329

VIP（概念版）

· 领取VIP
    路径：/youth/vip
    用例：/youth/vip
· 领取一天VIP
    路径：/youth/day/vip
    用例：/youth/day/vip?receive_day=2026-01-30
· 升级概念版VIP
    路径：/youth/day/vip/upgrade
    用例：/youth/day/vip/upgrade
· 获取当月已领取VIP天数
    路径：/youth/month/vip/record
    用例：/youth/month/vip/record
· 获取已领取VIP状态
    路径：/youth/union/vip
    用例：/youth/union/vip

歌手

· 获取歌手列表
    路径：/artist/lists
    用例：/artist/lists?sextypes=0&type=0&musician=0&hotsize=30
· 获取歌手详情
    路径：/artist/detail
    用例：/artist/detail?id=6539
· 获取歌手专辑
    路径：/artist/albums
    用例：/artist/albums?id=6539&page=1&pagesize=30&sort=hot
· 获取歌手单曲
    路径：/artist/audios
    用例：/artist/audios?id=6539&page=1&pagesize=30&sort=hot
· 获取歌手MV
    路径：/artist/videos
    用例：/artist/videos?id=6539&page=1&pagesize=30&tag=all
· 关注歌手
    路径：/artist/follow
    用例：/artist/follow?id=6539
· 取消关注歌手
    路径：/artist/unfollow
    用例：/artist/unfollow?id=6539
· 获取关注歌手新歌
    路径：/artist/follow/newsongs
    用例：/artist/follow/newsongs?last_album_id=xxx&pagesize=30&opt_sort=1

视频

· 获取视频URL
    路径：/video/url
    用例：/video/url?hash=视频hash
· 获取歌曲MV
    路径：/kmr/audio/mv
    用例：/kmr/audio/mv?album_audio_id=32155307&fields=mkv,tags
· 获取视频相关信息
    路径：/video/privilege
    用例：/video/privilege?hash=视频hash
· 获取视频详情
    路径：/video/detail
    用例：/video/detail?id=11517822

新歌/场景

· 新歌速递
    路径：/top/song
    用例：/top/song
· 场景音乐列表
    路径：/scene/lists
    用例：/scene/lists
· 场景音乐详情
    路径：/scene/module
    用例：/scene/module?id=9
· 获取场景音乐讨论区
    路径：/scene/list/v2
    用例：/scene/list/v2?id=9&page=1&pagesize=30&sort=rec
· 获取场景音乐模块Tag
    路径：/scene/module/info
    用例：/scene/module/info?id=9&module_id=83
· 获取场景音乐歌单列表
    路径：/scene/collection/list
    用例：/scene/collection/list?tag_id=42391
· 获取场景音乐视频列表
    路径：/scene/video/list
    用例：/scene/video/list?tag_id=42399
· 获取场景音乐音乐列表
    路径：/scene/audio/list
    用例：/scene/audio/list?id=9&module_id=173&tag=42391

每日/风格推荐

· 每日推荐
    路径：/everyday/recommend
    用例：/everyday/recommend?platform=ios
· 历史推荐
    路径：/everyday/history
    用例：/everyday/history?mode=song&history_name=RT_xxx&date=20240106
· 风格推荐
    路径：/everyday/style/recommend
    用例：/everyday/style/recommend?tagids=S14,S15,S16

排行榜

· 排行列表
    路径：/rank/list
    用例：/rank/list?withsong=1
· 排行榜推荐列表
    路径：/rank/top
    用例：/rank/top
· 排行榜往期列表
    路径：/rank/vol
    用例：/rank/vol?rankid=8888
· 排行榜信息
    路径：/rank/info
    用例：/rank/info?rankid=8888
· 排行榜歌曲列表
    路径：/rank/audio
    用例：/rank/audio?rankid=8888&rank_cid=76442

评论/收藏

· 歌曲收藏数
    路径：/favorite/count
    用例：/favorite/count?mixsongids=368015985,368015986
· 歌曲评论数
    路径：/comment/count
    用例：/comment/count?hash=歌曲hash 或 ?special_id=20505418
· 歌曲评论
    路径：/comment/music
    用例：/comment/music?mixsongid=302362878
· 歌曲评论-根据分类
    路径：/comment/music/classify
    用例：/comment/music/classify?mixsongid=302362878&type_id=12
· 歌曲评论-根据热词
    路径：/comment/music/hotword
    用例：/comment/music/hotword?mixsongid=302362878&hot_word=生活
· 楼层评论
    路径：/comment/floor
    用例：/comment/floor?special_id=100285259&mixsongid=302362878&tid=678433417
· 歌单评论
    路径：/comment/playlist
    用例：/comment/playlist?id=collection_3_1373407643_366_0
· 专辑评论
    路径：/comment/album
    用例：/comment/album?id=10729818

曲谱

· 歌曲曲谱
    路径：/sheet/list
    用例：/sheet/list?album_audio_id=302362878
· 曲谱详情
    路径：/sheet/detail
    用例：/sheet/detail?id=1564334343483305984&source=2
· 推荐曲谱
    路径：/sheet/hot
    用例：/sheet/hot?opern_type=1
· 曲谱合集
    路径：/sheet/collection
    用例：/sheet/collection?position=2
· 曲谱合集详情
    路径：/sheet/collection（注意与上面路径相同，参数不同）
    用例：/sheet/collection?collection_id=xxx&page=1

其他

· 提交听歌历史
    路径：/playhistory/upload
    用例：/playhistory/upload?mxid=32155307
· 获取服务器时间
    路径：/server/now
    用例：/server/now
· 刷刷
    路径：/brush
    用例：/brush
· AI推荐
    路径：/ai/recommend
    用例：/ai/recommend?album_audio_id=274565080,68435124

频道

· 获取用户所有频道
    路径：/youth/channel/all
    用例：/youth/channel/all?page=1&pagesize=30
· 频道详情
    路径：/youth/channel/detail
    用例：/youth/channel/detail?global_collection_id=11576464149
· 频道安利
    路径：/youth/channel/amway
    用例：/youth/channel/amway?global_collection_id=11576464149
· 相似频道
    路径：/youth/channel/similar
    用例：/youth/channel/similar?channel_id=11576464149
· 订阅频道
    路径：/youth/channel/sub
    用例：/youth/channel/sub?global_collection_id=11576464149&t=1
· 频道-音乐故事
    路径：/youth/channel/song
    用例：/youth/channel/song?global_collection_id=11576464149
· 频道-音乐故事详情
    路径：/youth/channel/song/detail
    用例：/youth/channel/song/detail?global_collection_id=11576464149&fileid=1720958083456581

动态

· 动态-最常访问
    路径：/youth/dynamic/recent
    用例：/youth/dynamic/recent

用户公开音乐

· 获取用户公开的音乐
    路径：/youth/user/song
    用例：/youth/user/song?userid=1354894105

听书

· 听书-每日推荐
    路径：/longaudio/daily/recommend
    用例：/longaudio/daily/recommend
· 听书-排行榜推荐
    路径：/longaudio/rank/recommend
    用例：/longaudio/rank/recommend
· 听书-VIP推荐
    路径：/longaudio/vip/recommend
    用例：/longaudio/vip/recommend
· 听书-每周推荐
    路径：/longaudio/week/recommend
    用例：/longaudio/week/recommend
· 听书-专辑详情
    路径：/longaudio/album/detail
    用例：/longaudio/album/detail?album_id=56655759
· 听书-专辑音乐列表
    路径：/longaudio/album/audios
    用例：/longaudio/album/audios?album_id=56655759

歌曲详情

· 歌曲成绩单
    路径：/song/ranking
    用例：/song/ranking?album_audio_id=32155307
· 歌曲成绩单详情
    路径：/song/ranking/filter
    用例：/song/ranking/filter?album_audio_id=32155307