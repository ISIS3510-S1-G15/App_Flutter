// List of restaurants for testing
import '../models/restaurant.dart';

final List<Restaurant> restaurants = [
  const Restaurant(
    id: '1',
    name: 'Starbucks',
    location: 'Plazoleta Lleras',
    category: 'Café',
    image: 'web/icons/starbucks.jpeg',
    isOpen: true,
    rating: 4.7,
    reviews: 1204,
    price: '\$',
    waitTime: '2-5 min',
    tags: ['Coffee', 'Pastries'],
    saved: true,
    hours: '6:30am - 8:00pm',
    description:
        'The campus favorite for specialty coffee, house-made pastries, and a cozy atmosphere perfect for studying or catching up with friends.',
    mapX: 55,
    mapY: 25,
    crowdingReports: [1, 1, 2, 1, 0, 1],
    menu: [
      MenuSection(category: 'Drinks', items: [
        MenuItem(name: 'Oat Latte', price: '\$15.250', desc: 'Double shot, oat milk, light foam'),
        MenuItem(name: 'Matcha Latte', price: '\$15.750', desc: 'Ceremonial grade, choice of milk'),
        MenuItem(name: 'Cold Brew', price: '\$14.500', desc: '18-hour steep, served over ice'),
      ]),
      MenuSection(category: 'Food', items: [
        MenuItem(name: 'Almond Croissant', price: '\$8.000', desc: 'Twice-baked, almond cream, toasted flakes'),
        MenuItem(name: 'Egg & Cheese Sandwich', price: '\$12.500', desc: 'Everything bagel, scrambled egg, cheddar'),
      ]),
    ],
  ),
  const Restaurant(
    id: '2',
    name: 'Yamato Sushi Wok',
    location: 'Calle 20',
    category: 'Asian',
    image: 'web/icons/sushi.png',
    isOpen: true,
    rating: 4.5,
    reviews: 673,
    price: '\$\$',
    waitTime: '10-15 min',
    tags: ['Ramen', 'Pho'],
    saved: false,
    hours: '11:30am - 9:00pm',
    description:
        'Authentic ramen, pho, and pan-Asian noodle dishes made fresh daily. Student favorite for a warm, satisfying meal between classes.',
    mapX: 70,
    mapY: 55,
    crowdingReports: [0, 1, 0, 0, 1],
    menu: [
      MenuSection(category: 'Ramen', items: [
        MenuItem(name: 'Tonkotsu Ramen', price: '\$20.500', desc: 'Rich pork broth, chashu, soft egg, nori'),
        MenuItem(name: 'Spicy Miso Ramen', price: '\$30.000', desc: 'Miso broth, tofu, corn, bamboo shoots'),
      ]),
      MenuSection(category: 'Pho', items: [
        MenuItem(name: 'Beef Pho', price: '\$22.000', desc: '12-hour broth, rare beef, herbs, bean sprouts'),
        MenuItem(name: 'Veggie Pho', price: '\$15.000', desc: 'Clear broth, tofu, mixed mushrooms'),
      ]),
    ],
  ),
  const Restaurant(
    id: '3',
    name: 'Cosechas',
    location: 'Calle 18',
    category: 'Smoothies',
    image: 'web/icons/cosechas.jpg',
    isOpen: true,
    rating: 4.4,
    reviews: 210,
    price: '\$',
    waitTime: '5 min',
    tags: ['Vegan options', 'Smoothies'],
    saved: true,
    hours: '7:00am - 5:00pm',
    description:
        'Cold-pressed juices, smoothie bowls, and protein shakes designed for active students. Everything is made to order.',
    mapX: 60,
    mapY: 35,
    crowdingReports: [2, 2, 1, 2, 2],
    menu: [
      MenuSection(category: 'Smoothies', items: [
        MenuItem(name: 'Green Machine', price: '\$8.500', desc: 'Spinach, banana, mango, ginger, coconut water'),
        MenuItem(name: 'Berry Boost', price: '\$8.500', desc: 'Mixed berries, açaí, almond butter, oat milk'),
      ]),
    ],
  ),
  const Restaurant(
    id: '4',
    name: 'La Puerta',
    location: 'Calle 19',
    category: 'Burgers',
    image: 'web/icons/la_puerta.png',
    isOpen: false,
    rating: 4.2,
    reviews: 340,
    price: '\$',
    waitTime: '5-10 min',
    tags: ['Burgers'],
    saved: true,
    hours: '11:30am - 8:00pm',
    description:
        'Classic campus grill serving smash burgers, crinkle fries, and tasty breakfast. Popular post-game spot for the athletics crowd.',
    mapX: 20,
    mapY: 70,
    crowdingReports: [0, 0, 1, 0],
    menu: [
      MenuSection(category: 'Burgers', items: [
        MenuItem(name: 'Classic Smash', price: '\$21.500', desc: 'Double smash patty, American cheese, pickles, special sauce'),
        MenuItem(name: 'Mushroom Swiss', price: '\$21.500', desc: 'Smash patty, sautéed mushrooms, Swiss cheese, truffle aioli'),
        MenuItem(name: 'Veggie Burger', price: '\$20.000', desc: 'House-made black bean patty, avocado, sprouts'),
      ]),
    ],
  ),
];