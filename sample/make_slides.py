# -*- coding: utf-8 -*-
"""生成 16:9 与 9:16 两套讲解用幻灯片（纯 PIL 绘制，便于复现）。"""
import os
from PIL import Image, ImageDraw, ImageFont

FONT_BOLD = "/System/Library/Fonts/STHeiti Medium.ttc"
BG = (246, 244, 239)
INK = (24, 24, 27)
MUTED = (110, 106, 99)
ACCENT = (194, 65, 12)
LINE = (216, 211, 201)


def font(size):
    return ImageFont.truetype(FONT_BOLD, size)


def wrap(draw, text, fnt, max_w):
    lines = []
    for seg in text.split("\n"):
        cur = ""
        for ch in seg:
            if draw.textlength(cur + ch, font=fnt) <= max_w:
                cur += ch
            else:
                lines.append(cur)
                cur = ch
        if cur:
            lines.append(cur)
    return lines


def base(W, H, idx, total, kicker):
    S = min(W, H)
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    m = int(S * 0.075)
    d.text((m, int(H * 0.07)), kicker, font=font(int(S * 0.022)), fill=MUTED)
    d.text((W - m - int(S * 0.085), int(H * 0.07)), f"{idx:02d} / {total:02d}",
           font=font(int(S * 0.022)), fill=MUTED)
    return img, d, m


def title_slide(W, H, idx, total, kicker, title, sub):
    S = min(W, H)
    img, d, m = base(W, H, idx, total, kicker)
    f = font(int(S * 0.095))
    y = int(H * 0.30)
    for ln in wrap(d, title, f, W - 2 * m):
        d.text((m, y), ln, font=f, fill=INK)
        y += int(S * 0.125)
    d.rectangle([m, y + int(S * 0.02), m + int(S * 0.09), y + int(S * 0.028)], fill=ACCENT)
    y += int(S * 0.07)
    for ln in wrap(d, sub, font(int(S * 0.032)), W - 2 * m):
        d.text((m, y), ln, font=font(int(S * 0.032)), fill=MUTED)
        y += int(S * 0.05)
    return img


def bullets_slide(W, H, idx, total, kicker, title, items):
    S = min(W, H)
    img, d, m = base(W, H, idx, total, kicker)
    d.text((m, int(H * 0.15)), title, font=font(int(S * 0.062)), fill=INK)
    y = int(H * 0.30)
    for no, (head, body) in enumerate(items, 1):
        d.ellipse([m, y + int(S * 0.008), m + int(S * 0.034), y + int(S * 0.042)], fill=ACCENT)
        d.text((m + int(S * 0.0105), y + int(S * 0.011)), str(no),
               font=font(int(S * 0.024)), fill=(255, 255, 255))
        d.text((m + int(S * 0.055), y), head, font=font(int(S * 0.038)), fill=INK)
        d.text((m + int(S * 0.055), y + int(S * 0.055)), body,
               font=font(int(S * 0.027)), fill=MUTED)
        y += int(H * 0.155)
    return img


def big_number_slide(W, H, idx, total, kicker, title, number, note):
    S = min(W, H)
    img, d, m = base(W, H, idx, total, kicker)
    d.text((m, int(H * 0.15)), title, font=font(int(S * 0.052)), fill=INK)
    d.text((m, int(H * 0.30)), number, font=font(int(S * 0.17)), fill=ACCENT)
    y = int(H * 0.55)
    for ln in wrap(d, note, font(int(S * 0.030)), W - 2 * m):
        d.text((m, y), ln, font=font(int(S * 0.030)), fill=MUTED)
        y += int(S * 0.045)
    return img


def bars_slide(W, H, idx, total, kicker, title, rows, note):
    S = min(W, H)
    img, d, m = base(W, H, idx, total, kicker)
    d.text((m, int(H * 0.14)), title, font=font(int(S * 0.054)), fill=INK)
    y = int(H * 0.27)
    maxv = max(v for _, v in rows)
    label_w = int(S * 0.20)
    bar_w = W - 2 * m - label_w - int(S * 0.10)
    for name, v in rows:
        d.text((m, y), name, font=font(int(S * 0.030)), fill=INK)
        w = int(bar_w * v / maxv)
        x0 = m + label_w
        d.rounded_rectangle([x0, y + int(S * 0.004), x0 + w, y + int(S * 0.036)],
                            radius=int(S * 0.016), fill=ACCENT)
        d.text((x0 + w + int(S * 0.015), y), f"{v}%", font=font(int(S * 0.026)), fill=MUTED)
        y += int(H * 0.105)
    d.text((m, H - int(H * 0.17)), note, font=font(int(S * 0.024)), fill=MUTED)
    return img


def formula_slide(W, H, idx, total, kicker, title, steps):
    S = min(W, H)
    img, d, m = base(W, H, idx, total, kicker)
    d.text((m, int(H * 0.14)), title, font=font(int(S * 0.054)), fill=INK)
    y = int(H * 0.28)
    bw, bh = W - 2 * m, int(H * 0.135)
    for k, v in steps:
        d.rounded_rectangle([m, y, m + bw, y + bh], radius=int(S * 0.02),
                            fill=(255, 255, 255), outline=LINE, width=2)
        d.text((m + int(S * 0.03), y + int(S * 0.028)), k,
               font=font(int(S * 0.036)), fill=ACCENT)
        d.text((m + int(S * 0.175), y + int(S * 0.030)), v,
               font=font(int(S * 0.030)), fill=INK)
        y += bh + int(S * 0.032)
    return img


def build(W, H, outdir):
    os.makedirs(outdir, exist_ok=True)
    slides = [
        title_slide(W, H, 1, 5, "RED DIVIDEND · 01", "红利ETF定投，\n到底在赌什么？",
                    "不是赌涨跌，是赌一门长期稳定的现金流生意。"),
        bars_slide(W, H, 2, 5, "RED DIVIDEND · 02", "你买的是一篮子什么公司",
                   [("银行", 24), ("煤炭", 18), ("电力", 15), ("交通运输", 13), ("其他", 30)],
                   "高股息、盈利稳、现金流好——行业分布本身就是风格。"),
        big_number_slide(W, H, 3, 5, "RED DIVIDEND · 03", "付了多少钱，决定未来的股息率",
                         "5.8%", "同样的分红，买入价越低，落到你口袋里的现金流就越厚。"),
        formula_slide(W, H, 4, 5, "RED DIVIDEND · 04", "分红再投入，才是复利的开关",
                      [("再投入", "分红自动买成份额，份额变多，下次分红更多"),
                       ("不复投", "分红变成现金躺在账户里，只剩单利")]),
        bullets_slide(W, H, 5, 5, "RED DIVIDEND · 05", "十年后拉开差距的三件事",
                      [("选对指数", "看编制规则与行业分布，而不是看名字"),
                       ("等好价格", "股息率高于历史中位数时，才值得加速"),
                       ("分红再投", "让份额替你工作，而不是让现金闲着")]),
    ]
    for i, img in enumerate(slides, 1):
        img.save(os.path.join(outdir, f"{i:02d}.png"), quality=95)


if __name__ == "__main__":
    root = os.path.dirname(os.path.abspath(__file__))
    build(1920, 1080, os.path.join(root, "16x9"))
    build(1080, 1920, os.path.join(root, "9x16"))
    print("done")
