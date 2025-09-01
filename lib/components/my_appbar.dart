import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constant.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  const MyAppBar({super.key, this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: false,
      backgroundColor: transparent,
      elevation: 0,
      flexibleSpace: Padding(
        padding: EdgeInsets.only(top: topPadding + 5),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 15),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: myBorderRadius(10),
                    boxShadow: [boxShadow1],
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: black,
                  ),
                ),
              ),
            ),
            if (title != null) Text(title!, style: blackMedium20),
            Spacer(),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Row(children: actions!),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 10);
}
