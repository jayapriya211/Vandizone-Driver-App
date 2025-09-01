import 'package:flutter/material.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import '../../../../components/my_appbar.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/assets.dart';
import '../../../../utils/constant.dart';
import '../../../../widgets/my_elevated_button.dart';

class CardView extends StatefulWidget {
  const CardView({super.key});

  @override
  State<CardView> createState() => _CardViewState();
}

class _CardViewState extends State<CardView> {
  final GlobalKey<FormState> formKey = GlobalKey();
  String cardNumber = '';
  String expiryDate = '';
  String cardHolderName = '';
  String cvvCode = '';
  bool isCvvFocused = false;

  void onCreditCardModelChange(CreditCardModel creditCardModel) {
    setState(() {
      cardNumber = creditCardModel.cardNumber;
      expiryDate = creditCardModel.expiryDate;
      cardHolderName = creditCardModel.cardHolderName;
      cvvCode = creditCardModel.cvvCode;
      isCvvFocused = creditCardModel.isCvvFocused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: "Card"),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero.copyWith(top: 10),
              physics: BouncingScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: CreditCardWidget(
                    backgroundImage: AssetImages.creditcardbg,
                    cardBgColor: white,
                    cardNumber: cardNumber,
                    expiryDate: expiryDate,
                    cardHolderName: cardHolderName,
                    cvvCode: cvvCode,
                    showBackView: isCvvFocused,
                    obscureCardNumber: true,
                    obscureCardCvv: true,
                    isHolderNameVisible: true,
                    cardType: CardType.visa,
                    onCreditCardWidgetChange: (e) {},
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: CreditCardForm(
                    formKey: formKey,
                    onCreditCardModelChange: onCreditCardModelChange,
                    obscureCvv: true,
                    obscureNumber: true,
                    // cursorColor: primary,
                    // textColor: black,
                    inputConfiguration: InputConfiguration(
                      cardHolderDecoration: InputDecoration(
                        labelText: "Name on card",
                        hintText: "Enter name on card",
                        hintStyle: colorABRegular16,
                        labelStyle: blackRegular18,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                      ),
                      cardNumberDecoration: InputDecoration(
                        labelText: "Card number",
                        hintText: "Enter card number",
                        hintStyle: colorABRegular16,
                        labelStyle: blackRegular18,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                      ),
                      expiryDateDecoration: InputDecoration(
                        labelText: "Expiry",
                        hintText: "Expiry",
                        hintStyle: colorABRegular16,
                        labelStyle: blackRegular18,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                      ),
                      cvvCodeDecoration: InputDecoration(
                        labelText: "Cvv",
                        hintText: "Cvv",
                        hintStyle: colorABRegular16,
                        labelStyle: blackRegular18,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black38),
                        ),
                      ),
                    ),
                    cardHolderName: '',
                    cardNumber: '',
                    cvvCode: '',
                    expiryDate: '',
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.vertical(top: myRadius(20)),
                boxShadow: [BoxShadow(blurRadius: 6, color: black.withValues(alpha: 0.15))]),
            padding: const EdgeInsets.all(20),
            child: MyElevatedButton(
              title: "Add",
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
                Navigator.pushNamed(context, Routes.successTransferOwner);
              },
            ),
          )
        ],
      ),
    );
  }
}
