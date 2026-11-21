# 🏰 NightSpire: Survival

Game 2D hành động sinh tồn Roguelite leo tháp cổ kính, phát triển trên nền tảng **Godot Engine 4.x**.

Người chơi chọn anh hùng, vượt qua 10 tầng ngục tối ngập tràn cạm bẫy và quái vật hung bạo, thu thập vàng, mua sắm nâng cấp trang bị và đánh bại Trùm Cuối trên đỉnh tháp.

---

## 🎮 Lối chơi & Tính năng nổi bật

- **Tiến trình 10 Tầng Tháp:**
  - Mỗi tầng là một đợt quái dồn dập với độ khó và mật độ tăng dần.
  - **Tầng 3 & 6:** Đại chiến Trùm (Miniboss) với tỉ lệ kích hoạt sự kiện **Song Đấu Trùm (Double Boss)** kịch tính.
  - **Tầng 9:** Cổ Tự An Toàn của **Thương Nhân (Sanctuary)** để mua sắm vật phẩm trước trận đại chiến.
  - **Tầng 10:** Trận chiến sinh tử cùng **Trùm Cuối (Final Boss)**.
- **Kho Vũ Khí & Phép Thuật:**
  - Tự động tấn công kẻ địch xung quanh với kiếm, dao găm, phi đao, trượng sấm sét...
  - Nâng cấp level vũ khí để tăng sát thương và mở rộng tầm đánh.
  - Hệ thống Bùa Phép: Cầu lửa (Fireball), Giáo dung nham (Molten Spear), Lốc xoáy (Tornado), Bão gai đất (Earth Spike).
- **Cổ Vật & Cửa Hàng (Shop & Buffs):**
  - Mua sắm trang bị sau mỗi tầng, hỗ trợ đổi đồ (Reroll).
  - Cổ vật bị động gia tăng sức mạnh: Giày tốc độ, Giáp sắt, Bùa nam châm hút vàng, Nhẫn máu, Cánh thần Hermes...
- **Hình Ảnh & Âm Thanh:**
  - Đồ họa Pixel Art hoài niệm cổ điển.
  - Hệ thống âm thanh sống động với **Dynamic Pitch** (cao độ âm thanh biến đổi linh hoạt, không lặp lại).
  - Tùy chỉnh chế độ Cửa sổ / Toàn màn hình và thanh trượt âm lượng chi tiết trong Cài đặt.

---

## 🕹️ Hướng dẫn điều khiển

| Phím | Hành động |
| :--- | :--- |
| **W, A, S, D** / **Phím Mũi Tên** | Di chuyển nhân vật |
| **Tự Động (Auto-Attack)** | Tự động tung chiêu và tấn công kẻ địch gần nhất |
| **ESC** | Tạm dừng game (Pause Menu) / Đóng Cửa hàng |

---

## 🚀 Cách cài đặt & Trải nghiệm

### Cách 1: Chơi trực tiếp bản Export (Releases)
1. Tải file nén `.zip` của game từ mục **[Releases](../../releases)** trên GitHub.
2. Giải nén vào thư mục bất kỳ.
3. Chạy file `NightSpire-Survival.exe` để chơi ngay!

### Cách 2: Mở dự án bằng Godot Engine
1. Tải và cài đặt **Godot Engine 4.x** (bản Standard).
2. Clone repository về máy:
   ```bash
   git clone https://github.com/khanh-dinh26/NightSpire-Survival.git
   ```
3. Mở Godot -> Chọn **Import** -> Chọn file `project.godot`.
4. Nhấn **F5** (hoặc nút Play góc trên bên phải) để bắt đầu chơi.

---

## 🛠️ Công nghệ sử dụng
- **Engine:** Godot Engine 4.7
- **Ngôn ngữ:** GDScript
- **Renderer:** GL Compatibility
