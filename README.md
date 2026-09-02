# Windows optimization scripts

Bộ script tối ưu Windows theo hướng **nhẹ, an toàn và có thể khôi phục**, dành cho máy tính cấu hình cũ nhưng vẫn cần giữ đầy đủ Windows Update, Microsoft Defender, Microsoft Store và các thành phần hệ thống quan trọng.

## Script hiện có

### Windows 11 Home 25H2 Lite Safe v1.1

File: [`win11-home-25h2-lite-safe-v1.1.ps1`](./win11-home-25h2-lite-safe-v1.1.ps1)

Đối tượng sử dụng:

- Windows 11 Home 25H2 x64.
- Intel Core thế hệ 4 trở lên.
- RAM từ 8 GB.
- Khuyến nghị sử dụng SSD.
- Phù hợp cho Office, duyệt web, học tập và máy gia đình.

> [!IMPORTANT]
> Script chỉ tối ưu Windows sau khi cài đặt. Script **không cài Windows**, không kích hoạt bản quyền và không vượt qua yêu cầu CPU, TPM 2.0 hoặc Secure Boot của Windows 11.

## Nguyên tắc an toàn

Script không thực hiện những thay đổi sau:

- Không tắt Microsoft Defender hoặc Windows Firewall.
- Không tắt Windows Update, BITS hoặc Task Scheduler.
- Không tắt Windows Search hoặc SysMain.
- Không xóa Microsoft Store, Edge, WebView2 hoặc WinRE.
- Không tắt pagefile.
- Không tắt Wi-Fi, Bluetooth, âm thanh hoặc dịch vụ máy in.
- Không xóa AppX provisioned package của toàn hệ thống.

Trước khi tối ưu, script cố gắng tạo **System Restore Point**, xuất bản sao registry và ghi log thao tác.

## Chuẩn bị

Trước khi chạy:

1. Sao lưu dữ liệu quan trọng.
2. Cắm sạc nếu sử dụng laptop.
3. Hoàn tất Windows Update và khởi động lại máy.
4. Đóng các ứng dụng đang làm việc.
5. Đăng nhập bằng tài khoản có quyền Administrator.

## Cách tải script

Mở trang [`win11-home-25h2-lite-safe-v1.1.ps1`](./win11-home-25h2-lite-safe-v1.1.ps1), chọn **Download raw file**, sau đó lưu vào thư mục `Downloads`.

Hoặc tải toàn bộ repository:

```powershell
git clone https://github.com/ndlong78/windows.git
cd windows
```

## Cách chạy bằng menu

### Bước 1: Mở PowerShell với quyền quản trị

Nhấn Start, tìm **Windows PowerShell**, nhấp chuột phải và chọn **Run as administrator**.

### Bước 2: Chuyển tới thư mục chứa script

Nếu file nằm trong Downloads:

```powershell
cd "$env:USERPROFILE\Downloads"
```

### Bước 3: Cho phép script chạy trong phiên hiện tại

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
Unblock-File .\win11-home-25h2-lite-safe-v1.1.ps1
```

Thiết lập `Scope Process` chỉ có hiệu lực trong cửa sổ PowerShell hiện tại và tự mất khi đóng cửa sổ.

### Bước 4: Khởi chạy

```powershell
.\win11-home-25h2-lite-safe-v1.1.ps1
```

Menu hiển thị:

```text
1. Audit system
2. Apply SAFE profile
3. Apply LITE profile (recommended for Gen 4-6)
4. Remove optional apps manually
5. Restore settings
6. Export diagnostic report
7. Open logs folder
0. Exit
```

## Trình tự sử dụng khuyến nghị

### Máy Intel Gen 4–6, RAM 8 GB, SSD

1. Chọn `1. Audit system`.
2. Đọc kết quả CPU, RAM, loại ổ đĩa, TPM, Secure Boot và pagefile.
3. Chọn `3. Apply LITE profile`.
4. Xác nhận bằng `Y`.
5. Chờ DISM hoàn tất rồi khởi động lại Windows.

### Máy Intel Gen 7 trở lên hoặc RAM 16 GB

1. Chọn `1. Audit system`.
2. Chọn `2. Apply SAFE profile`.
3. Xác nhận bằng `Y`.
4. Khởi động lại Windows.

Với LG Gram 17Z990, Intel Core i7-8565U và RAM 16 GB, nên bắt đầu bằng profile **SAFE**.

## Phân biệt SAFE và LITE

| Thành phần | SAFE | LITE |
|---|:---:|:---:|
| Kiểm tra phần cứng | Có | Có |
| Tắt hiệu ứng trong suốt | Có | Có |
| Giảm hiệu ứng giao diện | Có | Có |
| Tắt gợi ý ứng dụng tiêu dùng | Có | Có |
| Pagefile do Windows tự quản lý | Có | Có |
| Chế độ nguồn Balanced | Có | Có |
| Gỡ nhóm ứng dụng tiêu dùng mặc định | Không | Có |
| Chạy DISM component cleanup | Không | Có |

Profile LITE chỉ gỡ ứng dụng được chọn cho **tài khoản người dùng hiện tại**. Script không gỡ package nền của toàn hệ thống và không ảnh hưởng đến tài khoản Windows khác.

## Ứng dụng có thể gỡ

Nhóm mặc định của profile LITE:

- Clipchamp.
- Microsoft News.
- Microsoft Solitaire Collection.
- Feedback Hub.
- Xbox Gaming Overlay.
- Xbox TCUI.
- Xbox Identity Provider.
- Xbox Speech Overlay.

Mục `4. Remove optional apps manually` cho phép lựa chọn thêm Phone Link hoặc Windows Maps. Chỉ gỡ những ứng dụng chắc chắn không sử dụng.

## Chạy trực tiếp không qua menu

Script hỗ trợ tham số `-Action`:

```powershell
# Chỉ audit máy
.\win11-home-25h2-lite-safe-v1.1.ps1 -Action Audit

# Áp dụng SAFE
.\win11-home-25h2-lite-safe-v1.1.ps1 -Action Safe

# Áp dụng LITE
.\win11-home-25h2-lite-safe-v1.1.ps1 -Action Lite

# Chọn ứng dụng để gỡ
.\win11-home-25h2-lite-safe-v1.1.ps1 -Action Apps

# Khôi phục thiết lập
.\win11-home-25h2-lite-safe-v1.1.ps1 -Action Restore

# Xuất báo cáo
.\win11-home-25h2-lite-safe-v1.1.ps1 -Action Report
```

Các thao tác thay đổi hệ thống vẫn yêu cầu xác nhận trước khi áp dụng.

## Backup, log và báo cáo

Script lưu dữ liệu tại:

```text
C:\ProgramData\Win11-Home-25H2-Lite-Safe\
├── Backup\
└── Logs\
```

Báo cáo chẩn đoán được lưu trên Desktop:

```text
Desktop\Win11-Home-25H2-Lite-Safe-Reports\
```

Báo cáo gồm thông tin phần cứng, phiên bản Windows, tình trạng bộ nhớ, các tiến trình dùng RAM nhiều nhất và trạng thái những dịch vụ hệ thống cần được bảo vệ.

## Khôi phục

Chạy lại script và chọn:

```text
5. Restore settings
```

Chức năng này khôi phục hiệu ứng giao diện, gợi ý nội dung, pagefile tự động và chế độ nguồn Balanced.

> [!NOTE]
> Các ứng dụng AppX đã gỡ không được tự động cài lại bởi mục Restore. Nếu cần, hãy cài lại từ Microsoft Store.

Nếu Windows gặp sự cố nghiêm trọng, có thể sử dụng System Restore với điểm có tên bắt đầu bằng:

```text
Before-Win11-Home-25H2-Lite-Safe-
```

## Sau khi chạy

1. Khởi động lại Windows.
2. Chờ 3–5 phút sau khi đăng nhập.
3. Mở Task Manager bằng `Ctrl + Shift + Esc`.
4. Kiểm tra tab **Performance > Memory** và **Startup apps**.
5. Không cài thêm chương trình dọn RAM hoặc registry cleaner.

Windows sử dụng RAM trống làm bộ nhớ đệm, vì vậy RAM idle thấp nhất không phải là mục tiêu duy nhất. Điều quan trọng là máy phản hồi ổn định và không sử dụng pagefile liên tục khi mở trình duyệt hoặc Office.

## Kiểm tra tính toàn vẹn

SHA-256 của bản v1.1 hiện tại:

```text
0cebea25599b2fead0c0fcf99d614b937876fec6ff2622e7463b5faae362207a
```

Kiểm tra sau khi tải:

```powershell
Get-FileHash .\win11-home-25h2-lite-safe-v1.1.ps1 -Algorithm SHA256
```

## Lưu ý

- Script cần Windows PowerShell 5.1 và quyền Administrator.
- Restore Point có thể không tạo được nếu System Protection bị tắt hoặc Windows giới hạn tần suất tạo điểm khôi phục; script vẫn tiếp tục và ghi cảnh báo vào log.
- Quá trình DISM của profile LITE có thể mất vài phút.
- Nếu Audit báo ổ hệ thống là `Unknown`, hãy kiểm tra SSD/HDD tại **Task Manager > Performance > Disk**.
- Nên thử profile SAFE trước khi dùng LITE trên một cấu hình chưa được kiểm thử.
