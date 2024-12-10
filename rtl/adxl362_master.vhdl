-- Project      : 
-- Design       : 
-- Verification : 
-- Reviewers    : 
-- Module       : adxl362_master.vhdl
-- Parent       : none
-- Children     : none
-- Description  : SPI communication 

LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY adx362_master IS
    PORT (
        clk     : IN    STD_LOGIC;
        rst     : IN    STD_LOGIC;
        xdout   : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0);   -- x-axis data
        xvalid  : OUT   STD_LOGIC;                      -- x-axis valid
        cs      : OUT   STD_LOGIC;
        mosi    : OUT   STD_LOGIC;
        miso    : IN    STD_LOGIC;
        sclk    : OUT   STD_LOGIC);
END ENTITY adx362_master;

ARCHITECTURE serial_communication OF adx362_master IS
    -- constants
    CONSTANT SCLK_PERIOD        : UNSIGNED(5 DOWNTO 0)          := "110010";     -- d'50
    CONSTANT POWER_CTRL_REG     : STD_LOGIC_VECTOR(7 DOWNTO 0)  := "00101101";   -- h'2D
    CONSTANT POWER_CTRL_MODE    : STD_LOGIC_VECTOR(7 DOWNTO 0)  := "00100010";   -- h'02 (Measurement mode)
    CONSTANT REG_WRITE_INST     : STD_LOGIC_VECTOR(7 DOWNTO 0)  := "00001010";   -- h'0A
    CONSTANT REG_READ_INST      : STD_LOGIC_VECTOR(7 DOWNTO 0)  := "00001011";   -- h'0B
    CONSTANT ADDR_X_DATA_REG    : STD_LOGIC_VECTOR(7 DOWNTO 0)  := "00001000";   -- h'08
    CONSTANT ZERO_PADDING       : STD_LOGIC_VECTOR(7 DOWNTO 0)  := "00000000";
    CONSTANT FULL_MES_LENGTH    : UNSIGNED                      := "10111";      -- CONFIGURATION USES 24 BITS
    CONSTANT READ_REQ_LENGTH    : UNSIGNED                      := "01000";      -- READ REQUEST USES 16 BITS
    -- types
    TYPE state_type IS (IDLE, CONF_MODE_E, CONFG_DONE_E, READ_REQX_E, READ_XDATA_E, READ_DONE_E);
    SIGNAL state : state_type;
    -- signals
    SIGNAL message              : STD_LOGIC_VECTOR(23 DOWNTO 0); -- INSTRUCTION + ADDRES + DATA 
    SIGNAL sclk_reg             : STD_LOGIC;
    SIGNAL sclk_counter         : UNSIGNED(5 DOWNTO 0);
    SIGNAL xdout_reg            : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL xvalid_reg           : STD_LOGIC;
    SIGNAL neg_tran_condition   : STD_LOGIC; -- Frequently used condition
BEGIN
    -- Concurrent Conditional Assignments
    sclk                <= sclk_reg;
    neg_tran_condition  <= '1' WHEN (sclk_counter = SCLK_PERIOD - 1) AND (sclk_reg = '1') ELSE '0';
    
    -- SPI CLOCK GENERATOR 1 MHz
    sclk_gen : PROCESS (clk, rst)
    BEGIN
        IF rst = '1' THEN
            sclk_counter <= (OTHERS => '0');
            sclk_reg <= '0';
        ELSIF rising_edge(clk) THEN
            IF sclk_counter >= SCLK_PERIOD - 1 THEN
                sclk_counter <= (OTHERS => '0');
                sclk_reg <= NOT sclk_reg;
            ELSE
                sclk_counter <= sclk_counter + 1;
            END IF;
        END IF;
    END PROCESS;

    state_machine : PROCESS (clk, rst)
        VARIABLE bit_counter : UNSIGNED(4 DOWNTO 0);
    BEGIN
        IF rst = '1' THEN
            bit_counter := FULL_MES_LENGTH;                                 -- we'll count down
            message     <= REG_WRITE_INST & POWER_CTRL_REG & POWER_CTRL_MODE;   -- we'll start with the configuration
            cs          <= '1';
            mosi        <= '0';
            xvalid_reg  <= '0';
            xdout_reg   <= ZERO_PADDING;
            state       <= IDLE;
        ELSIF rising_edge(clk) THEN
            CASE(state) IS
                WHEN IDLE =>
                IF neg_tran_condition = '1' THEN
                    cs      <= '0';
                    mosi    <= message(to_integer(bit_counter));
                    state   <= CONF_MODE_E;
                END IF;
                WHEN CONF_MODE_E =>
                    mosi <= message(to_integer(bit_counter));
                    IF neg_tran_condition = '1' THEN
                        -- check for transition first
                        IF bit_counter = "00000" THEN
                            cs      <= '1';
                            state   <= CONFG_DONE_E;
                            bit_counter := FULL_MES_LENGTH;
                        ELSE
                            bit_counter := bit_counter - 1;
                        END IF;
                    END IF;
                WHEN CONFG_DONE_E =>
                    message <= REG_READ_INST & ADDR_X_DATA_REG & ZERO_PADDING;
                    IF neg_tran_condition = '1' THEN
                        cs      <= '0';
                        mosi    <= message(to_integer(bit_counter));
                        state   <= READ_REQX_E;
                    END IF;
                WHEN READ_REQX_E =>
                    mosi <= message(to_integer(bit_counter));
                    IF neg_tran_condition = '1' THEN
                        -- check for transition
                        IF bit_counter = READ_REQ_LENGTH THEN
                            state <= READ_XDATA_E;
                        END IF;

                        bit_counter := bit_counter - 1;
                    END IF;
                WHEN READ_XDATA_E =>
                    IF neg_tran_condition = '1' THEN
                        -- check for transition first
                        xdout_reg <= xdout_reg(6 DOWNTO 0) & miso; -- store received bits
                        IF bit_counter = "00000" THEN
                            cs          <= '1';
                            xvalid_reg  <= '1';
                            state       <= READ_DONE_E;
                            bit_counter := FULL_MES_LENGTH;
                        ELSE
                            bit_counter := bit_counter - 1;
                        END IF;
                    END IF;
                WHEN READ_DONE_E =>
                    message <= REG_READ_INST & ADDR_X_DATA_REG & ZERO_PADDING; -- ready for the next read request
                    IF neg_tran_condition = '1' THEN
                        cs          <= '0';
                        mosi        <= message(to_integer(bit_counter));
                        xvalid_reg  <= '0';
                        state       <= READ_REQX_E;
                    END IF;
                WHEN OTHERS => -- fault recovery
                    state <= IDLE;
            END CASE;
        END IF;
    END PROCESS;

    xdout_reg_pro : PROCESS (clk, rst)
    BEGIN
        IF rst = '1' THEN
            xdout <= ZERO_PADDING;
            xvalid <= '0';
        ELSIF rising_edge(clk) THEN
            xvalid <= xvalid_reg;
            IF xvalid_reg = '1' THEN
                xdout <= xdout_reg;
            END IF;
        END IF;
    END PROCESS;
END ARCHITECTURE;