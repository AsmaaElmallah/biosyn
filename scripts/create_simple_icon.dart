import 'dart:io';
import 'package:image/image.dart' as img;

/// Script to create a simple icon from blue-logo.png
/// This script crops the logo to show only the icon and "Biosyn" text
/// without "PHARMACEUTICALS"

void main() async {
  print('🎨 Creating simple icon...');
  
  try {
    // Read the original logo
    final logoFile = File('assets/blue-logo.png');
    if (!await logoFile.exists()) {
      print('❌ Error: assets/blue-logo.png not found');
      return;
    }
    
    print('📖 Reading original logo...');
    final originalBytes = await logoFile.readAsBytes();
    final originalImage = img.decodeImage(originalBytes);
    
    if (originalImage == null) {
      print('❌ Error: Could not decode image');
      return;
    }
    
    print('✅ Original image: ${originalImage.width}x${originalImage.height}');
    
    // Use the full image (no cropping) to show complete text
    final fullImage = originalImage;
    
    // Create a new image with white background and more padding
    final iconSize = 1024;
    // Increase padding to 18% on left/right and 12% on top/bottom for better spacing
    final horizontalPadding = (iconSize * 0.18).round(); // 18% padding from sides (more space)
    final verticalPadding = (iconSize * 0.12).round(); // 12% padding from top/bottom
    final contentWidth = iconSize - (horizontalPadding * 2);
    final contentHeight = iconSize - (verticalPadding * 2);
    
    print('🖼️ Creating ${iconSize}x${iconSize} icon with white background...');
    print('   Padding: ${horizontalPadding}px (horizontal), ${verticalPadding}px (vertical)');
    final iconImage = img.Image(width: iconSize, height: iconSize);
    
    // Fill with white background
    img.fill(iconImage, color: img.ColorRgb8(255, 255, 255));
    
    // Calculate scale to fit full image in content area
    // Scale down to 80% of available space to ensure text is fully visible with margins
    final availableWidth = (contentWidth * 0.80).round();
    final availableHeight = (contentHeight * 0.80).round();
    
    final scaleX = availableWidth / fullImage.width;
    final scaleY = availableHeight / fullImage.height;
    final scale = scaleX < scaleY ? scaleX : scaleY; // Use smaller scale to fit both dimensions
    
    // Ensure minimum readable size - if scale is too small, use a fixed scale
    final minScale = 0.20; // Minimum 20% of original size
    final finalScale = scale < minScale ? minScale : scale;
    
    final scaledWidth = (fullImage.width * finalScale).round();
    final scaledHeight = (fullImage.height * finalScale).round();
    
    // Center the scaled image with extra horizontal padding
    final offsetX = horizontalPadding + ((contentWidth - scaledWidth) ~/ 2);
    final offsetY = verticalPadding + ((contentHeight - scaledHeight) ~/ 2);
    
    print('📐 Scaling image to ${scaledWidth}x${scaledHeight} (scale: ${finalScale.toStringAsFixed(2)})...');
    print('   Position: x=$offsetX, y=$offsetY');
    print('   This ensures full text is visible with proper spacing');
    final scaledImage = img.copyResize(
      fullImage,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: img.Interpolation.cubic,
    );
    
    // Composite the scaled image onto white background
    img.compositeImage(iconImage, scaledImage, dstX: offsetX, dstY: offsetY);
    
    // Save the icon
    final outputFile = File('assets/icon-simple.png');
    await outputFile.parent.create(recursive: true);
    
    print('💾 Saving icon to assets/icon-simple.png...');
    await outputFile.writeAsBytes(img.encodePng(iconImage));
    
    print('✅ Icon created successfully!');
    print('   Size: ${iconSize}x${iconSize} pixels');
    print('   Location: assets/icon-simple.png');
    
  } catch (e, stackTrace) {
    print('❌ Error creating icon: $e');
    print('Stack trace: $stackTrace');
  }
}

