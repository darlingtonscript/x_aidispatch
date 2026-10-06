-- X AI Dispatch | MR X | X Studio
-- The resource also creates this table automatically on first start.

CREATE TABLE IF NOT EXISTS `x_dispatch_history` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `call_id` INT NOT NULL,
  `type` VARCHAR(48) NOT NULL,
  `title` VARCHAR(120) NOT NULL,
  `priority` TINYINT NOT NULL DEFAULT 2,
  `services` VARCHAR(120) NOT NULL,
  `origin` VARCHAR(16) NOT NULL DEFAULT 'player',
  `status` VARCHAR(16) NOT NULL,
  `reports` INT NOT NULL DEFAULT 1,
  `units` INT NOT NULL DEFAULT 0,
  `x` FLOAT NOT NULL DEFAULT 0,
  `y` FLOAT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
