const { Pool } = require('pg');
const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD
});

class Stockpile {
    static async findAll() {
        try {
            const result = await pool.query(
                `SELECT s.*, u.name as responsible_name 
                FROM stockpiles s 
                LEFT JOIN users u ON s.responsible_team_id = u.id 
                ORDER BY s.created_at DESC`
            );
            return result.rows;
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }

    static async findById(id) {
        try {
            const result = await pool.query(
                `SELECT s.*, u.name as responsible_name 
                FROM stockpiles s 
                LEFT JOIN users u ON s.responsible_team_id = u.id 
                WHERE s.id = $1`,
                [id]
            );
            return result.rows[0];
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }

    static async create(stockpileData) {
        try {
            const result = await pool.query(
                `INSERT INTO stockpiles 
                (name, material, grade, length, width, height, volume, location, responsible_team_id) 
                VALUES ($1, $2, $3, $4, $5, $6, $7, point($8, $9), $10) 
                RETURNING *`,
                [
                    stockpileData.name,
                    stockpileData.material,
                    stockpileData.grade,
                    stockpileData.length,
                    stockpileData.width,
                    stockpileData.height,
                    stockpileData.volume,
                    stockpileData.location.coordinates[0],
                    stockpileData.location.coordinates[1],
                    stockpileData.responsibleTeamId
                ]
            );
            return result.rows[0];
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }

    static async update(id, stockpileData) {
        try {
            const result = await pool.query(
                `UPDATE stockpiles 
                SET name = $1, material = $2, grade = $3, 
                    length = $4, width = $5, height = $6, 
                    volume = $7, location = point($8, $9), 
                    responsible_team_id = $10, 
                    updated_at = CURRENT_TIMESTAMP 
                WHERE id = $11 
                RETURNING *`,
                [
                    stockpileData.name,
                    stockpileData.material,
                    stockpileData.grade,
                    stockpileData.length,
                    stockpileData.width,
                    stockpileData.height,
                    stockpileData.volume,
                    stockpileData.location.coordinates[0],
                    stockpileData.location.coordinates[1],
                    stockpileData.responsibleTeamId,
                    id
                ]
            );
            return result.rows[0];
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }

    static async delete(id) {
        try {
            const result = await pool.query(
                'DELETE FROM stockpiles WHERE id = $1 RETURNING *',
                [id]
            );
            return result.rows[0];
        } catch (error) {
            console.error('Database error:', error);
            throw new Error('Database error occurred');
        }
    }
}

module.exports = Stockpile; 