# 🚀 Rails Facebook API - Product Management System

A modern Rails application with Facebook OAuth integration and comprehensive product management features.

## ✨ Features

- 🔐 **Facebook OAuth Authentication** - Secure login with Facebook
- 📦 **Product Management** - Create, edit, delete products with user ownership
- 🖼️ **Image Upload** - Active Storage integration for product images
- 🎨 **Modern UI** - Beautiful Tailwind CSS design with AOS animations
- 🛡️ **Security** - User-specific product access and validation
- 📱 **Responsive** - Mobile-friendly interface

## 🛠️ Tech Stack

- **Ruby** 3.4.1
- **Rails** 7.1.5.1
- **PostgreSQL** - Database
- **Tailwind CSS** - Styling
- **Active Storage** - File uploads
- **OmniAuth Facebook** - Authentication
- **AOS** - Scroll animations

## 📋 Requirements

- Ruby 3.4.1 or higher
- Rails 7.1+
- PostgreSQL
- Node.js (for asset compilation)
- Facebook App credentials

## ⚙️ Setup

### 1. Clone the repository
```bash
git clone https://github.com/Sup-Film/Rails-Facebook-API.git
cd Rails-Facebook-API
```

### 2. Install dependencies
```bash
bundle install
```

### 3. Environment Configuration
Create `.env` file in the root directory:
```env
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_CALLBACK_URL=http://localhost:3000/auth/facebook/callback
```

### 4. Database Setup
```bash
rails db:create
rails db:migrate
rails db:seed
```

### 5. Start the server
```bash
rails server
```

Visit `http://localhost:3000` to see the application.

## 🔧 Facebook App Configuration

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create a new app
3. Add Facebook Login product
4. Set Valid OAuth Redirect URIs:
   - `http://localhost:3000/auth/facebook/callback` (development)
   - `https://yourdomain.com/auth/facebook/callback` (production)
5. Copy App ID and App Secret to your `.env` file

## 📂 Project Structure

```
app/
├── controllers/
│   ├── application_controller.rb
│   ├── products_controller.rb
│   └── user_sessions_controller.rb
├── models/
│   ├── product.rb
│   └── user.rb
├── views/
│   ├── layouts/application.html.erb
│   ├── products/
│   └── home/
└── services/
    └── facebook_api_service.rb

config/
├── routes.rb
└── initializers/omniauth.rb
```

## 🚀 Key Features

### Authentication
- Facebook OAuth integration
- Secure session management
- Error handling for login failures
- User-friendly Thai language messages

### Product Management
- CRUD operations for products
- User ownership validation
- Image upload with Active Storage
- Responsive product cards
- Image zoom functionality

### UI/UX
- Modern Tailwind CSS design
- AOS scroll animations
- Mobile-responsive layout
- Toast notifications
- Loading states

## 🛡️ Security Features

- CSRF protection
- User-specific product access
- Input validation
- Secure file uploads
- OmniAuth error handling

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Sup-Film**
- GitHub: [@Sup-Film](https://github.com/Sup-Film)

## 🙏 Acknowledgments

- Rails community for excellent documentation
- Facebook for OAuth integration
- Tailwind CSS for beautiful styling
- Contributors and testers

---