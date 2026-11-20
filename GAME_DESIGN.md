# GAME DESIGN DOCUMENT (GDD) - NIGHTSPIRE SURVIVAL

## 1. Cốt truyện & Bối cảnh (Lore)
- **Bối cảnh:** Thế giới bị bao phủ bởi bóng tối vĩnh cửu từ các Tòa Tháp Hắc Ám (Spires). Mỗi tòa tháp bị trấn giữ bởi một Chúa Tể (Final Boss) mang thuộc tính riêng biệt.
- **Nhiệm vụ:** Người chơi vào vai một Kẻ Leo Tháp (Chọn class từ `rogues.png`), tiến vào từng tòa tháp, sống sót qua các đợt quái vật bảo vệ từng tầng, thu thập vũ khí/phước lành để hạ gục Chúa Tể ở đỉnh tháp.
- **Luật sinh tử (Permadeath):** Chết ở bất kỳ tầng nào sẽ xóa toàn bộ file save hiện tại (`user://savegame.json`), buộc phải leo lại từ Tầng 1.

## 2. Hệ thống Chọn Tháp (Tower Expeditions - Phong cách Nightreign)
Trước khi bắt đầu một lượt chơi (New Run), người chơi chọn 1 trong các Tòa Tháp. Mỗi tháp quyết định **gạch nền (`tiles.png`), chủng loại quái (`monsters.png`/`animals.png`), hiệu ứng môi trường và Boss cuối**:
1. **Tháp Rừng Độc (Blightwood Spire):**
   - *Môi trường:* Nền đất rừng, cây cối (`tiles.png`), quái thú & côn trùng (`animals.png`, nhện/rắn/dơi trong `monsters.png`).
   - *Hiệu ứng tháp:* Quái có tỷ lệ gây độc (rút máu theo thời gian).
   - *Boss cuối:* Chúa Tể Rừng Sâu (Độc/Triệu hồi).
2. **Tháp Hầm Mộ Cổ (Catacomb Spire):**
   - *Môi trường:* Gạch đá xanh tối, quan tài, ngọn đuốc (`tiles.png`, `animated-tiles.png`). Quái xương, hồn ma, tử linh (`monsters.png`).
   - *Hiệu ứng tháp:* Tốc độ hồi máu giảm 25%, nhưng lượng Vàng rơi ra tăng 30%.
   - *Boss cuối:* Đại Pháp Sư Tử Linh (Bắn đạn phép diện rộng).
3. **Tháp Lò Rèn Dung Nham (Cinderforge Spire):**
   - *Môi trường:* Gạch đỏ/đen, chậu lửa (`tiles.png`, `animated-tiles.png`). Quái Orc, Quỷ lửa, Người đá (`monsters.png`).
   - *Hiệu ứng tháp:* Sát thương của cả người chơi và quái đều tăng 25%.
   - *Boss cuối:* Ác Quỷ Chiến Tranh (Tấn công cận chiến & lao tới cực nhanh).

## 3. Cấu trúc 10 Tầng của một Tòa Tháp (Floor Progression)
Mỗi lượt leo tháp gồm đúng **10 Tầng** cố định theo nhịp sau:
- **Tầng 1, 2, 3 (Wave Thường):** Sống sót hết thời gian (25s - 35s). Xong tầng mở **Bảng Mua Đồ (3 thẻ)**.
- **Tầng 4 (Mini-Boss 1):** Tiêu diệt 1 Mini-Boss + quái phụ (không giới hạn thời gian). Hạ gục Mini-Boss sẽ rớt ra **5 vật phẩm/buff -> Người chơi được chọn lấy 2 món miễn phí**.
- **Tầng 5, 6, 7 (Wave Thường):** Sống sót hết thời gian (40s - 50s). Xong tầng mở **Bảng Mua Đồ (3 thẻ)**.
- **Tầng 8 (Mini-Boss 2):** Tiêu diệt Mini-Boss thứ 2 (mạnh hơn). Hạ gục rớt **5 vật phẩm/buff -> Chọn lấy 2 món miễn phí**.
- **Tầng 9 (Tầng Chuẩn Bị - NPC Sanctuary):**
  - Không có quái. Sân đấu có các NPC (lấy từ `rogues.png`) đứng cạnh rương/lửa trại (`tiles.png`, `animated-tiles.png`):
    - *NPC Thợ Rèn:* Bán & Nâng cấp vũ khí.
    - *NPC Giả Kim:* Bán bình máu hồi phục & Buff chỉ số vĩnh viễn.
    - *NPC Buôn Lậu:* Gacha vật phẩm bí ẩn giá cao.
  - Người chơi tiêu hết vàng tích trữ trước khi bước qua cửa lên đỉnh tháp.
- **Tầng 10 (Final Boss - Đỉnh Tháp):** Tiêu diệt Chúa Tể của tòa tháp để hoàn thành Run và mở khóa độ khó/tháp tiếp theo.

## 4. Cơ chế Cửa Hàng & Phần Thưởng
- **Bảng Mua Đồ cuối Wave thường (Tầng 1-3, 5-7):**
  - Hiển thị **3 thẻ ngẫu nhiên** (có thể là Vũ khí mới, Nâng cấp vũ khí trùng loại, hoặc Buff chỉ số).
  - Người chơi dùng Vàng nhặt được từ quái để mua (có thể mua cả 3 nếu đủ vàng).
  - Có nút **Làm mới (Reroll)** tốn vàng (giá tăng dần mỗi lần bấm).
- **Kho báu Mini-Boss (Tầng 4, 8):**
  - Hiển thị bảng **5 món đồ** (tỷ lệ đồ Rare/Epic cao). Người chơi click chọn tối đa **2 món** vào túi đồ mà không tốn vàng.

## 5. Kỹ thuật Hình ảnh & Animation (Static 32x32 Sprites)
- Toàn bộ sprite lấy từ 8 file ảnh 32x32 có sẵn.
- Dùng `Tween` trong Godot để tạo chuyển động: lắc lư góc nghiêng khi di chuyển, nhún co giãn khi đứng yên, chớp trắng + bóp dẹt khi trúng đạn.
- Vũ khí lấy từ `items.png` / `items-palette-swaps.png`, tách thành node riêng bay quanh nhân vật và tự động tấn công mục tiêu gần nhất.