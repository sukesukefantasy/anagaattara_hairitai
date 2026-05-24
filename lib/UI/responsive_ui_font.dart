/// ゲーム UI（MessageWindow / HUD 等）の共通フォントサイズ。
const double kGameUiMobileWidthBreakpoint = 600;
const double kGameUiMobileHeightBreakpoint = 500;

const double kGameUiFontSizeMobile = 12.0;
const double kGameUiFontSizeDesktop = 16.0;

bool isGameUiMobileLayout(double width, double height) =>
    width < kGameUiMobileWidthBreakpoint ||
    height < kGameUiMobileHeightBreakpoint;

double gameUiBaseFontSize(double width, double height) =>
    isGameUiMobileLayout(width, height)
        ? kGameUiFontSizeMobile
        : kGameUiFontSizeDesktop;
