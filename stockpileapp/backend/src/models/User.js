const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD
});

class User {
    static async findOne(email) {
        try {
            const result = await pool.query(
                'SELECT * FROM users WHERE email = $1',
                [email]
            );
            return result.rows[0];
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }

    static async findById(id) {
        try {
            const result = await pool.query(
                'SELECT * FROM users WHERE id = $1',
                [id]
            );
            return result.rows[0];
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }

    static async create(userData) {
        try {
            const hashedPassword = await bcrypt.hash(userData.password, 12);
            const result = await pool.query(
                'INSERT INTO users (email, password, name, role) VALUES ($1, $2, $3, $4) RETURNING *',
                [userData.email, hashedPassword, userData.name, userData.role || 'worker']
            );
            return result.rows[0];
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }

    static async comparePassword(password, hashedPassword) {
        return bcrypt.compare(password, hashedPassword);
    }

    static async updateLastLogin(id) {
        try {
            await pool.query(
                'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
                [id]
            );
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }
}

module.exports = User; 