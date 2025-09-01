import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import '../../../../utils/constant.dart';
import '../../../models/chat_msg.dart';
import '../../../utils/assets.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final List<ChatMsg> _chats = [
    ChatMsg(sendedByMe: false, msg: 'Okay', dateTime: "10:04 AM"),
    ChatMsg(sendedByMe: true, msg: 'Hello Mam\nI will reach in 10 min', dateTime: "10:04 AM"),
    ChatMsg(sendedByMe: false, msg: 'Hello', dateTime: "10:04 AM"),
  ];
  final _msgController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: _body(),
    );
  }

  Column _body() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(20).copyWith(top: 10),
            physics: BouncingScrollPhysics(),
            reverse: true,
            itemBuilder: (context, index) {
              final item = _chats[index];
              bool sendedByMe = item.sendedByMe;
              return Column(
                crossAxisAlignment: sendedByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        sendedByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisAlignment: sendedByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!sendedByMe)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child:
                              ClipOval(child: Image.asset(AssetImages.ride, height: 40, width: 40)),
                        ),
                      Column(
                        crossAxisAlignment:
                            sendedByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(maxWidth: 50.w),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: sendedByMe ? secoBtnColor : colorF2,
                                borderRadius: myBorderRadius(10).copyWith(
                                  bottomRight: myRadius(sendedByMe ? 0 : 10),
                                  bottomLeft: myRadius(!sendedByMe ? 0 : 10),
                                )),
                            child: Text(item.msg,
                                style: sendedByMe ? primaryMedium16 : blackRegular16),
                          ),
                          Gap(5),
                          Text(item.dateTime, style: colorABRegular14),
                        ],
                      )
                    ],
                  ),
                ],
              );
            },
            separatorBuilder: (_, __) => Gap(30),
            itemCount: _chats.length,
          ),
        ),
        Container(
          decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.vertical(top: myRadius(20)),
              boxShadow: [BoxShadow(blurRadius: 6, color: black.withValues(alpha: 0.15))]),
          padding: const EdgeInsets.all(20),
          child: Container(
            alignment: Alignment.center,
            height: 54,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: myBorderRadius(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      textInputAction: TextInputAction.send,
                      style: whiteMedium16,
                      onEditingComplete: _send,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write Your Message...',
                        hintStyle: whiteMedium16,
                      ),
                    ),
                  ),
                  InkWell(onTap: _send, child: Image.asset(AssetImages.send))
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  void _send() {
    final msg = _msgController.text;
    FocusScope.of(context).unfocus();
    if (msg.isEmpty) return;
    DateTime now = DateTime.now();
    String formattedTime = DateFormat('hh:mm a').format(now);
    _msgController.clear();
    _chats.insert(0, ChatMsg(sendedByMe: true, msg: msg, dateTime: formattedTime));
  }

  AppBar _appBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      elevation: 0,
      backgroundColor: transparent,
      flexibleSpace: Padding(
        padding: EdgeInsets.only(top: topPadding + 5),
        child: IntrinsicHeight(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Easther Howard', style: blackMedium18),
                    Text('Online', style: colorABRegular14),
                  ],
                ),
              ),
              Icon(Icons.more_vert, color: black),
              Gap(15),
            ],
          ),
        ),
      ),
    );
  }
}
