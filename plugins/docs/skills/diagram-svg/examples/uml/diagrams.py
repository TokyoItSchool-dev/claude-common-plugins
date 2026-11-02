"""8枚のUML図を umlsvg で生成する（UML正確性レビュー反映版）。
座標は元画像(1448x1086)のピクセル値を基準にしている。修正点は UML_review.md を参照。"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "scripts"))
from diagsvg import Doc, INK, ACCENT, BAND  # noqa: E402

OUT = os.path.join(HERE, "out") + os.sep


def deployment():
    d = Doc("UML 配置図", title_fs=76)
    d.node3d(52, 282, 364, 230, "利用者PC / スマートフォン", stereotype="device")
    d.artifact(92, 380, 284, 104, "ブラウザ", "executionEnvironment", icon="globe", sfs=15, tdx=70, idx=36)
    d.node3d(574, 280, 288, 234, "Webサーバ", stereotype="device")
    d.artifact(604, 380, 232, 104, "Webアプリ", icon="window")
    d.node3d(1011, 274, 350, 310, "アプリケーションサーバ", stereotype="device")
    d.artifact(1053, 368, 277, 88, "注文API", icon="gear")
    d.artifact(1053, 474, 277, 88, "商品API", icon="gear")
    d.node3d(594, 738, 284, 220, "DBサーバ", stereotype="device")
    d.artifact(622, 830, 230, 104, "注文DB", icon="db")
    d.node3d(1008, 740, 354, 220, "外部決済ゲートウェイ", stereotype="device")
    d.artifact(1043, 834, 288, 104, "決済サービス", icon="card")
    # 通信路：ノード2つを結ぶ関連。端の記号なし・分岐なし
    d.edge([(416, 408), (574, 408)], arrow=False)
    d.edge([(862, 408), (1011, 408)], arrow=False)
    d.edge("M1080,584 V648 H763 V702", arrow=False)
    d.edge("M1170,584 V648 H1203 V704", arrow=False)
    d.text(495, 396, "HTTPS", fs=24, weight=500, anchor="middle")
    d.text(936, 396, "HTTP", fs=24, weight=500, anchor="middle")
    d.text(920, 636, "JDBC", fs=24, weight=500, anchor="middle")
    d.text(1260, 636, "HTTPS", fs=24, weight=500, anchor="middle")
    d.footer("実行環境への配置構成を物理的に表す図。")
    d.save(OUT + "deployment.svg")


def component():
    d = Doc("UML コンポーネント図")
    d.component_box(427, 218, 385, 120, "Webフロント", fs=28)
    d.component_box(79, 487, 283, 118, "商品サービス")
    d.component_box(408, 487, 264, 120, "認証サービス")
    d.component_box(704, 487, 275, 123, "注文サービス")
    d.component_box(1165, 472, 250, 113, "在庫サービス")
    d.component_box(1167, 638, 249, 113, "決済連携")
    d.component_box(79, 860, 283, 104, "商品DB", "database", icon="db")
    d.component_box(413, 860, 285, 104, "会員DB", "database", icon="db")
    d.component_box(746, 858, 288, 113, "注文DB", "database", icon="db")
    d.component_box(1110, 858, 290, 113, "通知サービス")

    # 提供インターフェース：提供側から実線で白丸 / 利用側は白丸へ破線依存
    for x in (256, 573, 892):
        d.edge([(x, 487), (x, 406)], arrow=False)
        d.lollipop(x, 393)
    d.edge("M427,281 H256 V379", dash=True)
    d.edge("M573,338 V379", dash=True)
    d.edge("M812,281 H892 V379", dash=True)
    d.text(282, 386, "商品検索", fs=22, weight=500)
    d.text(282, 414, "インターフェース", fs=22, weight=500)
    d.text(599, 400, "認証インターフェース", fs=22, weight=500)
    d.text(918, 400, "注文インターフェース", fs=22, weight=500)

    # 組立コネクタ（ボール＆ソケット）：注文サービスが要求、在庫・決済が提供
    d.edge("M979,530 H1047", arrow=False)
    d.edge("M1081,530 H1165", arrow=False)
    d.lollipop(1068, 530); d.socket(1068, 530, "right")
    d.edge("M958,610 V696 H1047", arrow=False)
    d.edge("M1081,696 H1167", arrow=False)
    d.lollipop(1068, 696); d.socket(1068, 696, "right")
    d.text(994, 470, "在庫確認", fs=21, weight=500)
    d.text(994, 498, "インターフェース", fs=21, weight=500)
    d.text(996, 638, "決済処理", fs=21, weight=500)
    d.text(994, 666, "インターフェース", fs=21, weight=500)

    # 通知：通知サービスが提供、注文サービスが利用
    d.edge([(1255, 858), (1255, 834)], arrow=False)
    d.lollipop(1255, 821)
    d.edge("M925,610 V780 H1255 V806", dash=True)
    d.text(1000, 812, "通知インターフェース", fs=22, weight=500)

    # データアクセス：«use» 依存
    for x, y1, y2 in [(192, 605, 858), (524, 607, 858), (853, 610, 856)]:
        d.edge([(x, y1), (x, y2)], dash=True)
        d.stereo(x + 14, 742, "use", fs=21, anchor="start", layer="over")
    d.footer("システムを構成する部品と依存関係を示す図。")
    d.save(OUT + "component.svg")


def state():
    d = Doc("UML ステートマシン図")

    def st(x, y, w, h, name, behavior):
        d.box(x, y, w, h, band=50)
        d.text(x + w / 2, y + 35, name, fs=27, anchor="middle", layer="nodes")
        d.nodes.append(f'<line x1="{x}" y1="{y+50}" x2="{x+w}" y2="{y+50}" stroke="{INK}" stroke-width="2"/>')
        d.text(x + 18, y + 84, behavior, fs=19, weight=400, layer="nodes")

    st(316, 221, 212, 106, "新規", "entry / 注文番号採番")
    st(686, 221, 234, 106, "支払い待ち", "entry / 決済画面表示")
    st(1111, 221, 244, 106, "支払い済み", "entry / 入金記録")
    st(1112, 416, 244, 104, "出荷準備中", "do / 梱包")
    st(1112, 594, 244, 104, "発送済み", "entry / 追跡番号通知")
    st(1112, 768, 244, 102, "配送完了", "entry / 完了メール送信")
    st(604, 618, 254, 104, "キャンセル", "entry / 在庫戻し")
    d.start(115, 279)
    d.final(1234, 952)
    d.final(731, 860, r=28)

    d.edge("M142,279 H314")
    d.edge("M528,279 H684")
    d.edge("M920,279 H1109")
    d.edge("M820,327 V378 H880 V329")          # 自己遷移
    d.edge("M413,327 V667 H602")
    d.edge("M725,327 V616")
    d.edge("M1128,327 V349 H1069 V667 H860")
    d.edge("M1234,327 V414")
    d.edge("M1234,520 V592")
    d.edge("M1234,698 V766")
    d.edge("M1234,870 V917")
    d.edge("M731,722 V830")

    d.text(228, 265, "注文作成", fs=23, anchor="middle")
    d.text(606, 265, "決済開始", fs=23, anchor="middle")
    d.text(1014, 265, "決済完了", fs=23, anchor="middle")
    d.text(850, 406, "決済失敗", fs=22, anchor="middle")
    d.text(413, 520, "取消要求", fs=23, anchor="middle", bg=True)
    d.text(725, 520, "取消要求", fs=23, anchor="middle", bg=True)
    d.text(992, 500, "取消要求", fs=23, anchor="middle")
    d.text(992, 530, "/ 返金処理", fs=23, anchor="middle")
    d.text(1252, 378, "出荷指示", fs=23)
    d.text(1252, 563, "出荷 [梱包完了]", fs=23)
    d.text(1252, 740, "配達完了", fs=23)
    d.footer("状態の遷移とイベントの関係を示す図。")
    d.save(OUT + "state.svg")


def activity():
    d = Doc("UML アクティビティ図")
    d.raw(layer="bg", s=f'<rect x="123" y="182" width="1202" height="832" rx="6" fill="#fafcff" stroke="{INK}" stroke-width="3"/>')
    d.raw(layer="bg", s=f'<rect x="124.5" y="183.5" width="1199" height="59" fill="#d6eafd"/>')
    d.raw(layer="bg", s=f'<line x1="683" y1="182" x2="683" y2="1014" stroke="{INK}" stroke-width="3"/>')
    d.icon("person", 367, 213, s=0.8, layer="nodes")
    d.text(413, 225, "顧客", fs=30, layer="nodes")
    d.icon("gear", 931, 214, s=0.85, layer="nodes")
    d.text(973, 225, "システム", fs=30, layer="nodes")

    def act(x, y, w, h, label, icon, lx=None):
        d.plain(x, y, w, h, rx=10, sw=2.5)
        d.icon(icon, x + 50, y + h / 2, s=0.68)
        d.text(lx or x + 93, y + h / 2 + 8, label, fs=22)

    # 顧客レーン
    d.start(424, 266, r=17)
    d.diamond(424, 303, w=40, h=28)                   # マージ
    act(304, 341, 247, 52, "商品検索", "search")
    act(304, 420, 247, 54, "商品選択", "book")
    act(304, 497, 247, 54, "カート追加", "cart")
    d.diamond(424, 598)                               # 判断
    act(304, 657, 256, 54, "注文情報入力", "doc", lx=394)
    for y1, y2 in [(283, 287), (317, 339), (393, 418), (474, 495), (551, 573), (621, 655)]:
        d.edge([(424, y1), (424, y2)])
    d.edge("M392,598 H236 V303 H402")
    d.text(246, 588, "[買い物を続ける]", fs=20)
    d.text(436, 642, "[購入手続きへ]", fs=20)

    # システムレーン
    d.diamond(878, 573, w=40, h=28)                   # マージ
    act(741, 602, 275, 54, "支払い方法選択", "card", lx=838)
    act(741, 678, 275, 54, "決済処理", "gear", lx=853)
    d.diamond(878, 778, w=60, h=42)                   # 判断
    act(1100, 750, 204, 60, "エラー表示", "warn", lx=1177)
    act(741, 823, 275, 50, "注文確定", "check", lx=848)
    act(741, 890, 275, 52, "確認メール送信", "mail", lx=838)
    d.final(878, 983, r=23)
    d.edge("M560,684 H683 V573 H856")
    d.edge("M1211,750 V573 H900")
    for y1, y2 in [(587, 600), (656, 676), (732, 755), (799, 821), (873, 888), (942, 958)]:
        d.edge([(878, y1), (878, y2)])
    d.edge([(908, 778), (1098, 778)])
    d.text(950, 768, "[失敗]", fs=20)
    d.text(890, 815, "[成功]", fs=20)
    d.footer("処理の流れや分岐を表現する図。", y=1022, h=54)
    d.save(OUT + "activity.svg")


def sequence():
    d = Doc("UML シーケンス図")
    parts = [("顧客", "person", 51, 187), ("Web画面", "window", 290, 186), ("注文サービス", "gear", 527, 188),
             ("在庫サービス", "cube", 763, 187), ("決済サービス", "card", 996, 184), ("注文DB", "db", 1224, 175)]
    cx = {}
    for name, ic, x, w in parts:
        c = x + w / 2
        cx[name] = c
        d.plain(x, 193, w, 114, rx=8, fill="#dcecfd", sw=2.5)
        d.icon(ic, c, 233, s=0.9, layer="nodes")
        d.text(c, 290, name, fs=24, anchor="middle", layer="nodes")
        d.edge([(c, 307), (c, 982)], arrow=False, dash=True, sw=2)

    def act(name, y1, y2, w=25):
        c = cx[name]
        d.raw(f'<rect x="{c-w/2}" y="{y1}" width="{w}" height="{y2-y1}" rx="4" fill="{BAND}" stroke="{ACCENT}" stroke-width="2.5"/>')

    act("顧客", 344, 512); act("顧客", 935, 965)
    act("Web画面", 362, 396); act("Web画面", 425, 458); act("Web画面", 488, 965)   # 同期呼び出し中は活性を継続
    act("注文サービス", 540, 912, 26)
    act("在庫サービス", 592, 652); act("決済サービス", 692, 758, 26); act("注文DB", 797, 858, 26)
    W, O, S, P, DB = cx["Web画面"], cx["注文サービス"], cx["在庫サービス"], cx["決済サービス"], cx["注文DB"]

    def msg(y, x1, x2, n, label, reply=False):
        d.edge([(x1, y), (x2, y)], dash=reply, sw=2.5, arrow=True if reply else "filled")
        bx = min(x1, x2) + 46
        d.badge(bx, y - 22, n)
        d.text(bx + 26, y - 14, label, fs=21)

    msg(378, 155, W - 13, 1, "商品選択()")
    msg(441, 155, W - 13, 2, "カート追加()")
    msg(504, 155, W - 13, 3, "注文依頼()")
    msg(556, W + 13, O - 13, 4, "注文登録()")
    msg(608, O + 13, S - 13, 5, "在庫引当()")
    msg(648, S - 13, O + 13, 6, "引当結果", reply=True)
    msg(712, O + 13, P - 13, 7, "決済要求()")
    msg(754, P - 13, O + 13, 8, "決済結果", reply=True)
    msg(812, O + 13, DB - 13, 9, "注文保存()")
    msg(854, DB - 13, O + 13, 10, "保存完了", reply=True)
    msg(908, O - 13, W + 13, 11, "注文完了", reply=True)
    msg(958, W - 13, 157, 12, "完了画面表示", reply=True)
    d.footer("オブジェクト間のやり取りを時間順に示す図。", y=1016, h=58)
    d.save(OUT + "sequence.svg")


def classes():
    d = Doc("UML クラス図")
    d.classbox(278, 195, 300, "顧客", ["-  顧客ID : String", "-  氏名 : String", "-  メールアドレス : String"],
               ["+  会員登録() : void", "+  情報更新() : void"])
    d.classbox(853, 195, 317, "ショッピングカート", ["-  カートID : String", "-  作成日 : Date"],
               ["+  商品追加(商品 : 商品) : void", "+  商品削除(商品 : 商品) : void", "+  合計計算() : int"])
    d.classbox(268, 500, 318, "注文", ["-  注文ID : String", "-  注文日 : Date", "-  状態 : 注文状態", "-  合計金額 : int"],
               ["+  注文確定() : void", "+  キャンセル() : void", "+  合計計算() : int"])
    d.classbox(720, 521, 215, "注文明細", ["-  明細ID : String", "-  数量 : int", "-  小計金額 : int"],
               ["+  小計計算() : int"])
    d.classbox(1080, 509, 259, "商品", ["-  商品ID : String", "-  書名 : String", "-  価格 : int", "-  在庫数 : int"],
               ["+  在庫確認() : boolean", "+  在庫減少(数量 : int): void"], fs=19)
    d.classbox(262, 833, 333, "支払い", ["-  支払いID : String", "-  支払い方法 : String", "-  支払い金額 : int", "-  支払い日時 : Date"],
               ["+  支払い実行() : boolean", "+  返金処理() : void"], head=36, row=23, pad=6, fs=20)
    # 列挙型（注文.状態 の型。ステートマシン図の状態と一致）
    lits = ["新規", "支払い待ち", "支払い済み", "出荷準備中", "発送済み", "配送完了", "キャンセル"]
    x, y, w = 800, 790, 300
    d.box(x, y, w, 60 + 23 * 4 + 14, band=60, rx=6)
    d.nodes.append(f'<line x1="{x}" y1="{y+60}" x2="{x+w}" y2="{y+60}" stroke="{INK}" stroke-width="2"/>')
    d.stereo(x + w / 2, y + 24, "enumeration", fs=17)
    d.text(x + w / 2, y + 50, "注文状態", fs=24, anchor="middle", layer="nodes")
    for i, l in enumerate(lits):
        d.text(x + 22 + (i % 2) * 140, y + 84 + (i // 2) * 23, l, fs=19, weight=400, layer="nodes")

    # 関連
    d.edge([(578, 282), (853, 282)], arrow=False)
    d.text(707, 268, "所有する ▶", fs=22, anchor="middle", weight=500)
    d.edge([(428, 422), (428, 498)])                               # 顧客 → 注文（誘導可能）
    d.edge([(612, 613), (718, 613)]); d.diamond_end(586, 613)      # コンポジション
    d.edge([(935, 613), (1078, 613)])                              # 注文明細 → 商品
    d.edge([(428, 788), (428, 831)])                               # 注文 → 支払い
    for x, y, s in [(594, 272, "1"), (834, 272, "1"), (408, 452, "1"), (380, 486, "0..*"), (606, 598, "1"),
                    (668, 598, "1..*"), (948, 640, "*"), (1060, 640, "1"), (408, 808, "1"), (440, 826, "0..1")]:
        d.text(x, y, s, fs=21, weight=500)
    d.text(445, 464, "注文する", fs=22, weight=500)
    d.text(658, 644, "含む", fs=22, anchor="middle", weight=500)
    d.text(1005, 598, "対象商品", fs=22, anchor="middle", weight=500)
    d.text(498, 826, "支払いを行う", fs=20, weight=500)
    d.footer("クラスの構造と関係を静的に表す図。", y=1021, h=55)
    d.save(OUT + "class.svg")


def usecase():
    d = Doc("UML ユースケース図")
    d.raw(layer="bg", s=f'<rect x="313" y="188" width="824" height="803" rx="6" fill="#fafcff" stroke="{INK}" stroke-width="3"/>'
          f'<rect x="314.5" y="189.5" width="821" height="58" fill="#d6eafd"/>')
    d.text(725, 230, "オンライン書店システム", fs=30, anchor="middle", layer="nodes")
    left = [(290, "会員登録"), (370, "ログイン"), (450, "商品検索"), (530, "商品詳細閲覧"),
            (610, "カートに追加"), (690, "注文履歴確認"), (790, "注文する")]
    for cy, l in left:
        d.ellipse(554, cy, 127, 34, l)
    d.ellipse(596, 926, 127, 38, "支払い")
    d.ellipse(1000, 331, 112, 40, "在庫更新")
    d.ellipse(1006, 790, 115, 40, "クーポン利用")
    d.raw('<use href="#i-actor" x="80" y="480" width="80" height="112"/>')
    d.text(118, 627, "顧客", fs=30, anchor="middle", layer="nodes")
    d.raw('<use href="#i-actor" x="1282" y="282" width="80" height="112"/>')
    d.text(1322, 432, "管理者", fs=30, anchor="middle", layer="nodes")
    # 外部システムのアクターは «actor» 矩形
    d.plain(1196, 870, 230, 100, rx=6, fill="#eef6ff")
    d.stereo(1311, 905, "actor", fs=19)
    d.text(1311, 940, "外部決済サービス", fs=24, anchor="middle", layer="nodes")
    # 関連（端の黒丸なし）
    for cy, _ in left[:-1]:
        d.edge([(155, 525), (428, cy)], arrow=False)
    d.edge("M155,525 C230,650 270,790 427,790", arrow=False)
    d.edge([(1280, 357), (1112, 333)], arrow=False)
    d.edge([(723, 926), (1196, 926)], arrow=False)
    # include は基底 → 包含、extend は拡張 → 基底
    d.edge("M688,760 L768,722 V372 H683", dash=True, sw=2.5)
    d.edge([(891, 790), (683, 790)], dash=True, sw=2.5)
    d.edge([(596, 824), (596, 886)], dash=True, sw=2.5)
    d.stereo(778, 548, "include", fs=21, anchor="start", layer="over")
    d.stereo(790, 776, "extend", fs=21, anchor="middle", layer="over")
    d.stereo(609, 862, "include", fs=21, anchor="start", layer="over")
    d.footer("利用者とシステム機能の関係を表す図。", y=1020, h=56)
    d.save(OUT + "usecase.svg")


def package():
    d = Doc("UML パッケージ図")
    L = dict(tab=(100, 22), band=50, fs=30, fill="#f8fbff")
    S = dict(tab=(58, 16), fs=25, icon_dx=58, label_dx=114)
    d.folder(308, 203, 773, 173, title="プレゼンテーション層", **L)
    d.folder(400, 281, 285, 75, "画面", "window", **S)
    d.folder(721, 281, 267, 75, "API", "gear", **S)
    d.folder(258, 423, 874, 171, title="アプリケーション層", **L)
    d.folder(289, 500, 252, 77, "注文管理", "doc", **{**S, "icon_dx": 54, "label_dx": 100})
    d.folder(570, 500, 259, 77, "在庫管理", "cube", **{**S, "label_dx": 106})
    d.folder(857, 500, 255, 77, "ユーザー管理", "users", **{**S, "icon_dx": 56, "label_dx": 98, "fs": 23})
    d.folder(258, 644, 874, 170, title="ドメイン層", **L)
    d.folder(289, 720, 252, 77, "商品", "book", **S)
    d.folder(570, 720, 256, 77, "注文", "cart", **{**S, "label_dx": 108})
    d.folder(857, 720, 251, 77, "顧客", "person", **{**S, "label_dx": 112})
    d.folder(327, 857, 736, 146, title="インフラ層", **{**L, "band": 48})
    d.folder(392, 927, 272, 64, "DBアクセス", "db", **{**S, "label_dx": 100})
    d.folder(757, 927, 272, 64, "外部決済連携", "card", **{**S, "label_dx": 104})
    for y1, y2 in [(376, 421), (594, 642), (814, 855)]:
        d.edge([(696, y1), (696, y2)], dash=True, sw=2.5)
        d.stereo(710, (y1 + y2) / 2 + 7, "use", fs=19, anchor="start", layer="over")
    d.edge("M1133,506 H1243 V932 H1066", dash=True, sw=2.5)
    d.stereo(1188, 494, "use", fs=19, layer="over")
    d.footer("機能群をパッケージに分け、依存関係を整理して示す図。", y=1018, h=56)
    d.save(OUT + "package.svg")


ALL = (deployment, component, state, activity, sequence, classes, usecase, package)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in ALL:
        f()
