# v1 只交付 macOS

窗口操作 API 按操作系统切开，v1 只做 macOS。Windows/Linux 不进范围，避免三套残缺适配器。Relative Frame / Layout Action / Custom Control / Overlay Session 仍保持无 UI 的领域核，不把几何计算焊进窗口控件层，以便以后换适配器。
