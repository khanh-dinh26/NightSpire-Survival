# ANTIGRAVITY DEVELOPMENT & ARCHITECTURE RULES

## 1. Giới hạn hành vi của AI (Strict Boundaries)
- **Nguồn tài nguyên duy nhất:** Chỉ sử dụng 8 file ảnh trong `res://assets/sprites/` (`tiles.png`, `animals.png`, `animated-tiles.png`, `autotiles.png`, `items.png`, `items-palette-swaps.png`, `monsters.png`, `rogues.png`). Không tự ý sinh hoặc tải thêm file ảnh bên ngoài.
- **Kiểm soát phạm vi sửa đổi:** Chỉ tạo hoặc chỉnh sửa các file nằm trong danh sách của Milestone hiện tại.
- **Không tự ý thao tác Git:** Không chạy bất kỳ lệnh `git` nào nếu chưa được người dùng cho phép.
- **Luôn xác nhận kế hoạch trước khi viết code:** Liệt kê danh sách file sẽ tạo/sửa trước khi thực hiện.

## 2. Kiến trúc dữ liệu (Data-Driven với Godot Resources)
Mọi nội dung của tháp, quái, vật phẩm và NPC phải được tách khỏi logic code bằng `Resource` (`.tres`) để dễ mở rộng:
- `TowerData.gd` (`Resource`): Chứa `tower_name`, `lore_description`, `floor_tile_coords`, `tower_modifier_type`, `common_enemies: Array[EnemyData]`, `miniboss_pool: Array[EnemyData]`, `final_boss: EnemyData`.
- `FloorConfig.gd` (`Resource`): Định nghĩa loại tầng (`COMBAT_WAVE`, `MINIBOSS`, `NPC_SANCTUARY`, `FINAL_BOSS`), thời lượng wave, hệ số máu/sát thương quái.
- `ItemData.gd` (`Resource`): Chứa `id`, `name`, `type` (`WEAPON` hoặc `PASSIVE_BUFF`), `rarity` (`COMMON`, `RARE`, `EPIC`, `LEGENDARY`), `price`, `sprite_region`, `stats_modifier: Dictionary`.

## 3. Cấu trúc thư mục chuẩn
res://
├── assets/
│   ├── sprites/          # 8 file sprite sheet gốc (32x32)
│   └── audio/            # Âm thanh hiệu ứng
├── src/
│   ├── autoloads/
│   │   ├── EventBus.gd       # Signal trung tâm (wave_ended, boss_killed, item_bought, player_died)
│   │   ├── GameManager.gd    # Quản lý current_tower, current_floor (1..10), gold, player_inventory
│   │   └── SaveManager.gd    # Lưu/Xóa file user://savegame.json (Permadeath)
│   ├── resources/        # Định nghĩa class Resource (TowerData, EnemyData, ItemData)
│   ├── data/             # Các file .tres cụ thể (towers/, enemies/, items/)
│   ├── entities/
│   │   ├── player/       # Player.tscn, Player.gd
│   │   ├── enemies/      # EnemyBase.tscn, BossBase.tscn
│   │   ├── weapons/      # WeaponBase.tscn, Projectile.tscn
│   │   └── npcs/         # MerchantNPC.tscn (Dùng cho Tầng 9)
│   ├── arena/
│   │   ├── Arena.tscn    # Sân đấu tự đổi TileMap theo TowerData
│   │   └── Spawner.gd    # Xử lý sinh quái theo loại tầng (Wave thường vs Boss)
│   └── ui/
│       ├── TowerSelect.tscn  # Màn hình chọn Tháp & Class đầu game
│       ├── HUD.tscn          # Thanh máu, Vàng, Số tầng (VD: Floor 4/10 - MINI BOSS)
│       ├── WaveShopUI.tscn   # Bảng mua 3 món sau wave thường (Tầng 1-3, 5-7)
│       ├── BossDraftUI.tscn  # Bảng chọn 2 trong 5 món sau Mini-Boss (Tầng 4, 8)
│       └── GameOverUI.tscn   # Màn hình thua cuộc & xác nhận xóa save
├── GAME_DESIGN.md
└── ARCHITECTURE_RULES.md

## 4. Quy chuẩn Code & Lưu trữ
- **Godot 4 Strict Typing:** Bắt buộc khai báo kiểu tĩnh cho toàn bộ biến và hàm.
- **Pixel Art:** Bật `Default Texture Filter = Nearest` trong Project Settings.
- **Logic Permadeath Save:**
  - `SaveManager.save_run()` chỉ được gọi **sau khi người chơi đóng UI phần thưởng/cửa hàng** và chuẩn bị bước sang tầng tiếp theo (lưu `tower_id`, `next_floor_index`, `gold`, `current_hp`, `equipped_weapons`, `passives`).
  - Khi `EventBus.player_died` phát tín hiệu, `SaveManager.delete_save()` phải chạy ngay lập tức để xóa vĩnh viễn file save.