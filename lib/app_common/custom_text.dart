import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomText extends StatefulWidget {
  final String? text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? fontSize;
  final int? maxlines;
  const CustomText({super.key, this.text, this.style, this.textAlign, this.fontSize, this.maxlines});

  @override
  State<CustomText> createState() => _CustomTextState();
}

class _CustomTextState extends State<CustomText> {
  @override
  Widget build(BuildContext context) {
    return Text(
      widget.text!,
      style: widget.style??GoogleFonts.inter(),
      textAlign: widget.textAlign,
      maxLines: widget.maxlines,
    );
  }
}
