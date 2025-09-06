import 'package:flutter/material.dart';

// class CustomIosSwitch extends StatefulWidget {
//   final bool value;
//   final ValueChanged<bool> onChanged;
//
//   const CustomIosSwitch({
//     Key? key,
//     required this.value,
//     required this.onChanged,
//   }) : super(key: key);
//
//   @override
//   State<CustomIosSwitch> createState() => _CustomIosSwitchState();
// }
//
// class _CustomIosSwitchState extends State<CustomIosSwitch> {
//   late bool _isOn;
//
//   @override
//   void initState() {
//     super.initState();
//     _isOn = widget.value;
//   }
//
//   @override
//   void didUpdateWidget(CustomIosSwitch oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.value != widget.value) {
//       setState(() {
//         _isOn = widget.value;
//       });
//     }
//   }
//
//   void _toggleSwitch() {
//     setState(() {
//       _isOn = !_isOn;
//       widget.onChanged(_isOn);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _toggleSwitch,
//       child: AnimatedContainer(
//         duration: Duration(milliseconds: 200),
//         width: 36, // smaller
//         height: 20, // smaller
//         padding: EdgeInsets.symmetric(horizontal: 2),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(20),
//           color: !_isOn ? Colors.green : Colors.red,
//         ),
//         child: AnimatedAlign(
//           duration: Duration(milliseconds: 200),
//           alignment: !_isOn ? Alignment.centerRight : Alignment.centerLeft,
//           child: Container(
//             width: 16,
//             height: 16,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 1,
//                   offset: Offset(0, 1),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
class CustomIosSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomIosSwitch({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<CustomIosSwitch> createState() => _CustomIosSwitchState();
}

class _CustomIosSwitchState extends State<CustomIosSwitch> {
  late bool _isOn;

  @override
  void initState() {
    super.initState();
    _isOn = widget.value;
  }

  @override
  void didUpdateWidget(CustomIosSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _isOn = widget.value;
      });
    }
  }

  void _toggleSwitch() {
    setState(() {
      _isOn = !_isOn;
      widget.onChanged(_isOn);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleSwitch,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 36,
        height: 20,
        padding: EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _isOn ? Colors.green : Colors.red,
        ),
        child: AnimatedAlign(
          duration: Duration(milliseconds: 200),
          alignment: _isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

