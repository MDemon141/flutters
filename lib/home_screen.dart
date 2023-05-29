import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  List ctg = [
    "Foods",
    "Drinks",
    "Snacks",
    "Sauces",
    "Desserts",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(top: 50, left: 30, right: 40),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(
                  Icons.sort,
                  size: 50,
                ),
                Padding(padding: EdgeInsets.fromLTRB(50, 0, 0, 0)),
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.face_2_sharp,
                    size: 30,
                  ),
                )
              ]),
              SizedBox(
                height: 30,
              ),
              Text("Delicious",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  )),
              Text("food for you",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  )),
              Padding(padding: EdgeInsets.all(15)),
              Container(
                height: 60,
                width: 350,
                decoration: BoxDecoration(
                  color: Color.fromARGB(73, 148, 147, 147),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.all(20),
                alignment: Alignment.centerLeft,
                child: Icon(Icons.search),
              ),
              SizedBox(
                height: 50,
                child: ListView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 100,
                        child: Center(
                          child: ListTile(
                            title: Text(
                              ctg[index],
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
              ),
              SizedBox(
                height: 20,
              ),
              Padding(padding: EdgeInsets.only(top: 60)),
              SizedBox(
                  height: 250,
                  child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 30),
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 10),
                                height: 280,
                                width: 190,
                                decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 202, 202, 202),
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                          ],
                        );
                      })),
            ],
          ),
        ),
      ),
    );
  }
}
